# Ejecutar las directivas de la Base de Conocimiento desde una API

**Rama de trabajo propuesta:** `feat/kbase_directive_api` (sale de `develop`)
**Estado:** solo plan — no hay código escrito
**Fecha:** 2026-09-03

---

## 1. Qué se pide

Un endpoint al que un sistema externo (n8n, un bot propio, otro servidor) le manda una
directiva y una pregunta, y recibe en JSON lo que la directiva recupera y lo que el
agente contestaría — **sin enviar nada a ninguna conversación de Chatwoot**.

```
POST /api/v1/accounts/:account_id/knowledge_base/directive
api_access_token: <token>

{ "directive": "@buscar_predefinidas(GESTION)",
  "query":     "necesito actualizar mis datos fiscales" }

  ↓

{ "mode": "canned_response", "group": "GESTION", "threshold": 0.45,
  "items": [ { "title": "GESTION - Datos fiscales", "similarity": 0.65, ... } ],
  "reply": "Para actualizar tus datos fiscales...",
  "source": "Respuestas predefinidas", "resolved": true }
```

---

## 2. Por qué no es enchufar lo que ya hay

El motor existe y funciona, pero **nace de un `Message` y muere enviando un mensaje**.
`KnowledgeBaseResponseService#perform` no devuelve texto: devuelve `true`/`false` y el
texto se fue por `send_reply` a la conversación.

```
                      HOY (único camino)

  Cliente escribe
        │
        ▼
  ContactTrackingResponseAnalyzerJob
        │  KnowledgeBaseResponseService.new(message, tracking:, branch:)
        ▼
  ┌──────────────────────────────────────────────────────────────┐
  │ KnowledgeBaseResponseService                                 │
  │                                                              │
  │  detect_directive ──► RouteMap / KnowledgeBase::Directives   │
  │  search_queries   ──► lee @conversation.messages   ◄── ATADO │
  │  search_items     ──► embeddings + pgvector                  │
  │  generate_contextual_reply ──► OpenAI (@tracking, @inbox)    │
  │  save_history     ──► ESCRIBE en conversation      ◄── ATADO │
  │  send_reply       ──► CREA un Message              ◄── ATADO │
  │                                                              │
  │  return true/false  ← el texto NO sale de aquí               │
  └──────────────────────────────────────────────────────────────┘
```

Lo único que hoy se puede consumir por API es `POST /knowledge_base/search`, que es
búsqueda vectorial cruda: **no entiende directivas** (no lee `@buscar_predefinidas`), no
filtra por `source_type` ni por grupo, usa umbral 0.7 fijo por defecto y no redacta.
Sirve para depurar el índice, no para ejercitar el motor.

### 2.1 Inventario de acoplamientos

Cada fila es algo que hay que resolver para correr sin conversación:

| Punto del servicio | De qué depende hoy | En modo API |
|---|---|---|
| `@message.content` | `Message` | `query` del request |
| `search_queries` (turno corto hereda tema) | `@conversation.messages` últimos 2 entrantes | `context[]` opcional del request |
| `@message.sender&.name` | `Contact` | `contact_name` opcional → `"cliente"` |
| `load_history` / `save_history` | `conversation.additional_attributes['kb_history']` | `history[]` del request; **nunca se persiste** |
| `resolved_model` | `EngineConfig.model_for(@inbox)` | `inbox_id` opcional; sin él cae a `gpt-4o-mini` ⚠ |
| `@discourse` | hook Discourse **del inbox** | `inbox_id` obligatorio para ese modo |
| `agent_system_prompt`, objetivo, `branch_scope_rule` | `@tracking` (ContactTracking) | `template_id` opcional, o nada |
| `with_branch_tag` | `@route` (solo con `@ruta`) | solo si se resolvió rama |
| `send_reply` | `MessageBuilder` + `bot_user` | **no se ejecuta**: el texto vuelve en el JSON |

Lo que **no** toca este trabajo: el escalamiento y el alta de tickets (`@crear_ticket`)
viven en `ContactTrackingResponseAnalyzerJob`, no en el servicio. La API no puede abrir
tickets ni por accidente.

---

## 3. Arquitectura propuesta

### Opción A — un núcleo, dos entradas *(recomendada)*

Se extrae el motor a `KnowledgeBase::DirectiveRunner`, que recibe un **contexto plano**
(un Struct, sin ActiveRecord de conversación) y devuelve un **resultado plano**. El
servicio actual queda como adaptador: arma el contexto desde el mensaje, llama al runner
y envía la respuesta. El controlador arma el contexto desde el JSON y la devuelve.

```
   Conversación real                         Sistema externo
          │                                        │
          │ message + tracking                     │ JSON + api_access_token
          ▼                                        ▼
  ┌───────────────────────┐              ┌──────────────────────────┐
  │ KnowledgeBaseResponse │              │ KnowledgeBaseController  │
  │ Service (adaptador)   │              │ #directive               │
  │  · arma Context       │              │  · arma Context          │
  │  · send_reply         │              │  · render json           │
  │  · save_history       │              │  · NO envía, NO guarda   │
  └───────────┬───────────┘              └───────────┬──────────────┘
              │                                      │
              └──────────────┬───────────────────────┘
                             ▼
             ┌───────────────────────────────────────┐
             │ KnowledgeBase::DirectiveRunner        │
             │                                       │
             │  detect  → Directives / RouteMap      │
             │  scope   → grouped_items, threshold   │
             │  search  → embeddings + pgvector      │
             │  compose → OpenAI                     │
             │                                       │
             │  → Result(mode, group, threshold,     │
             │           items, reply, source, tag,  │
             │           resolved, reason)           │
             └───────────────────────────────────────┘
```

**Por qué esta y no una copia:** el catálogo `KnowledgeBase::Directives` existe
justamente porque esa cadena vivía duplicada en dos archivos, divergieron, y el bug
`@buscar_predeterminadas` hubo que arreglarlo en cuatro sitios a la vez (está
documentado en la cabecera de `directives.rb`). Una segunda implementación "solo para la
API" repite esa historia: a los dos meses el endpoint contesta distinto que el agente y
deja de servir para probar nada.

**Costo honesto:** F1 toca el camino vivo del agente en producción, y hoy
`KnowledgeBaseResponseService` **no tiene un solo spec** (el único que hay es
`spec/services/knowledge_base/directives_spec.rb`, del catálogo). Además el CI del repo
no corre — los workflows piden un runner `self-hosted` que no existe. Por eso F1 empieza
escribiendo la red de seguridad, no el refactor.

### Opción B — servicio aparte solo para la API

Más rápida y sin riesgo para el agente vivo, pero es la copia que ya salió mal una vez.
Se descarta salvo que se pida entrega urgente; en ese caso se documenta como deuda.

---

## 4. Contrato del endpoint

### Request

```jsonc
POST /api/v1/accounts/:account_id/knowledge_base/directive
Content-Type: application/json
api_access_token: <token>

{
  "directive":    "@buscar_predefinidas(GESTION)", // o "@buscar_articulo", "{{hoja:Precios}}"...
  "query":        "necesito actualizar mis datos fiscales",

  "context":      ["mensaje previo del cliente"],  // opcional — alimenta la 2a búsqueda
  "history":      [{ "q": "...", "a": "..." }],    // opcional — máx 6, no se persiste
  "contact_name": "María",                         // opcional — default "cliente"
  "inbox_id":     12,                              // opcional; OBLIGATORIO para @discourse
  "template_id":  5226,                            // opcional — toma prompt y objetivo del Agente IA
  "compose":      true,                            // false = solo recupera, no llama al LLM
  "limit":        3,                               // opcional — override de max_results
  "threshold":    0.45                             // opcional — override del umbral
}
```

Reglas de resolución de entrada:

- `query` es obligatorio.
- `directive` **o** `template_id`: uno de los dos. Con `template_id` solo, la directiva
  sale del `complementary_prompt` de ese Agente IA — así se prueba el agente real. Si
  vienen los dos, gana `directive` (el prompt del agente sigue usándose para el tono).
- `compose:false` ahorra la llamada al chat (queda solo el embedding): es el modo barato
  para verificar recuperación y umbrales.

### Response — 200

```jsonc
{
  "directive":  "@buscar_predefinidas(GESTION)",
  "mode":       "canned_response",
  "group":      "GESTION",
  "threshold":  0.45,
  "queries":    ["necesito actualizar mis datos fiscales"], // las que realmente se embebieron
  "items": [
    { "id": 812, "title": "GESTION - Datos fiscales", "content": "...",
      "source_type": "canned_response", "source_id": 44,
      "knowledge_source_id": 3, "metadata": {}, "similarity": 0.650 }
  ],
  "reply":    "Para actualizar tus datos fiscales...",
  "source":   "Respuestas predefinidas",   // la etiqueta que el agente pone al pie
  "tag":      "#gestion",                  // solo si la rama la declara
  "branch":   { "name": "comercial_gestion", "description": "quiere que hagamos algo" },
  "model":    "gpt-4o",
  "resolved": true
}
```

`resolved` es el mismo `true`/`false` que hoy devuelve el servicio: *"¿habría contestado
el agente en este turno?"*. Cuando es `false`, `reason` dice por qué — y esa distinción
es la mitad del valor del endpoint:

| `reason` | Significa | Equivalente en el log de hoy |
|---|---|---|
| `no_directive` | El texto no pide ninguna fuente | `⏭️ Sin directiva kbase → skip` |
| `no_match` | Se buscó y nada superó el umbral | `⚠️ Sin resultados en …` |
| `embedding_failed` | Ninguna consulta pudo embeberse | `items.nil?` |
| `llm_empty` | Recuperó, pero el modelo no redactó | `reply_text.blank?` |
| `branch_without_source` | La rama decidida no consulta nada (guion) | rama sin fuente |

Con `no_match` los `items` van vacíos pero se devuelve `threshold`, para que quien
depura vea contra qué se comparó. Útil sobre todo con grupo: `@buscar_predefinidas(X)`
exige 0.45 y el corpus general 0.20, y esa diferencia explica la mayoría de los "no me
contestó".

### Errores

| Código | Cuándo |
|---|---|
| 400 | falta `query`, o faltan `directive` y `template_id` |
| 404 | `template_id` / `inbox_id` no son de esta cuenta |
| 422 | directiva no reconocida · fuente inexistente o inactiva · sin integración OpenAI en la cuenta · `{{doc:}}`/`{{hoja:}}` sin la feature `google_calendar` · `@discourse` sin `inbox_id` o sin hook activo |
| 429 | throttle (§6) |
| 502 | OpenAI o Discourse no respondieron |

---

## 5. Modos soportados y en qué fase entra cada uno

```
  Directiva                    Fuente               Llamadas externas      Fase
  ───────────────────────────────────────────────────────────────────────────────
  @buscar_predefinidas(G)      pgvector local       embedding + chat        F2
  @buscar_articulo             pgvector local       embedding + chat        F2
  {{doc:nombre}}               pgvector local       embedding + chat        F2
  {{hoja:nombre}} (FAQ)        pgvector local       embedding + chat        F2
  ───────────────────────────────────────────────────────────────────────────────
  {{hoja:nombre}} (Datos)      Google Sheets        Sheets + chat           F3
  @buscar_foro(fuente)         Discourse AI         N× HTTP + sleep + chat  F3
  @discourse                   Discourse AI (inbox) N× HTTP + sleep + chat  F3
  {{consulta:...}}             BD del ERP           conexión externa        F3 ▲
  ───────────────────────────────────────────────────────────────────────────────
  @ruta(...) — clasifica rama  la que diga la rama  + 1 chat del router     F4
```

▲ `{{consulta:}}` se evalúa aparte: interpola datos del ERP del **contacto**, y en modo
API no hay contacto. O se exige `contact_id`, o queda fuera del endpoint. Decisión a
tomar en F3; por defecto **queda fuera** y responde 422.

El corte F2/F3 no es cosmético: los modos de F2 responden en ~1–3 s, mientras que
`@buscar_foro` hace una llamada por post con `sleep(1.5)` entre medio para no chocar con
el rate limit de Discourse — 10 s o más de request. Si F3 se entrega, va con timeout
propio y avisado en la doc.

---

## 6. Autenticación, permisos y costo

El endpoint cuelga de `Api::V1::Accounts::BaseController`, así que hereda el esquema de
siempre: header `api_access_token`.

```
  Token de USUARIO (agente/admin)        Token de AGENT BOT
  ───────────────────────────────        ──────────────────────────────────
  Funciona hoy sin tocar nada            authenticate_access_token! ✅
  Gasta un asiento de agente             validate_bot_access_token! ❌ BLOQUEA
  Revocarlo afecta a una persona         ↳ hay que agregar el endpoint a
                                            BOT_ACCESSIBLE_ENDPOINTS
                                         Identidad propia, revocable sola
```

**Recomendado: token de AgentBot.** Es la identidad correcta para un sistema externo — no
consume asiento y se revoca sin tocar la cuenta de nadie. Requiere una línea en
`app/controllers/concerns/access_token_auth_helper.rb`:

```ruby
BOT_ACCESSIBLE_ENDPOINTS = {
  ...
  'api/v1/accounts/knowledge_base' => %w[directive]
}.freeze
```

⚠ Esa constante es global: al abrirla, **cualquier** AgentBot de **cualquier** cuenta
puede pegarle al endpoint (siempre dentro de su propia cuenta, que sigue acotada por
`current_account`). Es el mismo alcance que ya tienen `conversations#create` y
`messages#create`, así que no abre una superficie de otra naturaleza — pero conviene
decidirlo a ojos abiertos.

Segundo punto a decidir: `KnowledgeBaseController` **no llama a `check_authorization`**
hoy — cualquier miembro de la cuenta puede listar items y disparar syncs. El endpoint
nuevo hereda esa laxitud. Propuesta: dejarlo igual que el resto del controlador (coherencia)
y anotar la revisión de Pundit del controlador completo como trabajo aparte.

### Costo — por qué el límite no es decorativo

Cada llamada gasta **la clave OpenAI de la cuenta** (`hooks` app_id `openai`, sin fallback
a ENV): 1–2 embeddings + 1 chat completion; con `@ruta`, un chat extra del clasificador.
Un bucle mal escrito del lado del cliente es una factura, no un timeout.

- Throttle por cuenta en `config/initializers/rack_attack.rb`, siguiendo el patrón de
  `contacts/search`: `RATE_LIMIT_KBASE_DIRECTIVE`, default **60/min**.
- `history` topeada a 6 entradas y `context` a 3, para que el request no infle el prompt.
- `compose:false` documentado como el modo por defecto para pruebas masivas.

### Modelo — la trampa

`resolved_model` sale de `EngineConfig.model_for(@inbox)`. **Sin `inbox_id` el endpoint cae
a `gpt-4o-mini`**, y está medido que ese modelo no cumple las reglas del prompt del
agente mientras que `gpt-4o` sí. Es decir: probar por API sin `inbox_id` puede dar una
respuesta peor que la de producción y hacer creer que el prompt está mal. Dos medidas:

1. `model` siempre presente en la respuesta, para que se vea con qué se contestó.
2. Si no viene `inbox_id`, agregar `"warning": "sin inbox_id se usó el modelo por defecto (gpt-4o-mini); producción puede usar otro"`.

---

## 7. Lo que la API **no** puede reproducir

Honestidad por adelantado, porque afecta cómo se leen los resultados:

- **Turnos cortos.** En producción, una pregunta de ≤8 palabras o que arranca con "y…"
  dispara una segunda búsqueda con el tema heredado de los 2 mensajes entrantes previos.
  Sin conversación no hay de dónde heredarlo: si el cliente no manda `context[]`, un
  `"y para 20?"` por API recupera distinto que en vivo. La respuesta devuelve `queries`
  con lo que realmente se embebió, así que la diferencia es visible, no silenciosa.
- **Historial.** `kb_history` vive en la conversación. Por API se manda o no existe, y
  nunca se escribe.
- **Rama (`@ruta`).** El clasificador usa los 4 mensajes anteriores como contexto
  reciente. Por API se aproxima con `context[]`; con la rama forzada a mano (`branch`)
  la clasificación se saltea entera y se ahorra la llamada.

### Efectos secundarios prohibidos en modo API

```
  ✗ send_reply          — no se crea ningún Message
  ✗ automatizaciones    — al no haber mensaje, no se dispara ninguna
  ✗ webhooks            — ídem
  ✗ save_history        — no se escribe conversation.additional_attributes
  ✗ @crear_ticket       — vive en el job, nunca en el runner
  ✓ lecturas            — knowledge_items, knowledge_sources, hooks, tracking_templates
  ✓ OpenAI / Discourse  — llamadas salientes de solo lectura
```

Esto se blinda por construcción: `DirectiveRunner` **no recibe** ni conversación ni
mensaje, así que no tiene con qué enviar ni dónde escribir.

---

## 8. Fases

```
 F0 ── Contrato cerrado (este documento) ─────────────────────── sin código
 F1 ── Red de seguridad + extracción del núcleo
        · spec de caracterización de KnowledgeBaseResponseService
          (los 4 modos pgvector, grupo positivo, grupo negado, sin match)
        · KnowledgeBase::DirectiveRunner + Context + Result
        · el servicio pasa a delegar; su comportamiento no cambia
        · verificación: los specs nuevos pasan antes y después
 F2 ── Endpoint /knowledge_base/directive — modos pgvector
        · ruta, acción, serialización, códigos de error, compose:false
        · request spec con OpenAI stubbeado
 F3 ── Modos externos: Discourse, hoja modo Datos, decisión sobre {{consulta:}}
        · timeouts propios y aviso de latencia en la doc
 F4 ── @ruta: template_id + clasificación de rama + branch forzada
 F5 ── Endurecimiento: BOT_ACCESSIBLE_ENDPOINTS, throttle rack-attack,
        topes de history/context, doc de uso para el sistema externo
```

F1 es la fase con riesgo (toca producción) y **debe entregarse sola**, sin endpoint, para
que si algo se rompe se sepa que fue la extracción y no la superficie nueva. F2 ya es
aditiva: código nuevo que no altera ningún camino existente.

---

## 9. Archivos que toca

| Archivo | Qué |
|---|---|
| `app/services/knowledge_base/directive_runner.rb` | **nuevo** — núcleo headless |
| `app/services/knowledge_base/context.rb` | **nuevo** — entrada plana (Struct) |
| `app/services/knowledge_base/result.rb` | **nuevo** — salida plana |
| `app/services/knowledge_base_response_service.rb` | pasa a adaptador; conserva `send_reply`, `save_history`, `with_branch_tag` |
| `app/controllers/api/v1/accounts/knowledge_base_controller.rb` | acción `directive` |
| `config/routes.rb` | `post 'knowledge_base/directive'` |
| `app/controllers/concerns/access_token_auth_helper.rb` | whitelist del bot (F5) |
| `config/initializers/rack_attack.rb` | throttle (F5) |
| `spec/services/knowledge_base/directive_runner_spec.rb` | **nuevo** |
| `spec/requests/api/v1/accounts/knowledge_base_spec.rb` | **nuevo** |

`app/services/knowledge_base/directives.rb` **no se toca**: el catálogo ya es el punto
único y el runner lo consume tal cual.

---

## 10. Decisiones pendientes

1. **Token**: ¿AgentBot (recomendado, requiere abrir la whitelist) o token de usuario
   agente/admin (funciona ya, gasta asiento)?
2. **`{{consulta:}}`**: ¿queda fuera del endpoint (422) o se soporta exigiendo `contact_id`?
3. **Discourse (F3)**: ¿entra, sabiendo que un request puede tardar 10 s o más?
4. **Pundit**: ¿se aprovecha para exigir administrador en este endpoint, o se mantiene la
   laxitud actual del controlador y la revisión de permisos va aparte?
