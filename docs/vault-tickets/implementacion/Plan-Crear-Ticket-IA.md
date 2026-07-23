# Plan — `@crear_ticket` inteligente (intake IA en seguimientos)

> Estado: 📝 **Propuesta / solo diseño** (2026-07-23). No implementado.
> Objetivo: que la directiva `@crear_ticket` deje de crear tickets "en blanco"
> y arme un ticket **bien formado** (título claro, descripción/resumen real,
> tipo/prioridad/clasificación derivados de la conversación), guiado por el
> prompt complementario del Agente IA.
> Relacionado: [[Plan-Ticket-Cerrado]] · [[Plan-Practicidad-osTicket]] · [[Pendiente]] · [[Historial-de-implementacion]]

---

## 1. Por qué

Hoy `@crear_ticket` es **un interruptor**, no una instrucción.

```ruby
# ticket_creator_service.rb:50
def directive_present?
  @tracking&.complementary_prompt.to_s.include?(DIRECTIVE)   # '@crear_ticket'
end
```

Cuando se dispara, el ticket nace con **valores fijos**:

```ruby
# orchestrator_service.rb:31 — find_or_create_from_message
CaseTicket.create!(
  case_type: default_case_type,        # el tipo por defecto, no el que corresponde
  priority:  :medium,                  # SIEMPRE media
  title:     title_from_message(msg),  # = message.content.truncate(100)
  # description: (vacía)
)
enqueue_ai_classification(ticket)      # async, y clasifica A CIEGAS
```

Y el clasificador IA que corre después **solo ve el título** (la descripción va
vacía) y **no lee la conversación**:

```ruby
# classifier.rb — user_prompt
TÍTULO: #{ticket.title}
DESCRIPCIÓN: #{ticket.description.presence || '(sin descripción)'}
```

### Diagnóstico

| Campo del ticket | Hoy | Debería |
|---|---|---|
| Título | mensaje recortado a 100 (literal) | frase clara del problema |
| Descripción | **vacía** | resumen 2–3 líneas del caso |
| Prioridad | `medium` fija | derivada (impacto×urgencia / reglas del prompt) |
| Tipo | tipo por defecto | inferido de la conversación |
| kind/impacto/urgencia | clasificado sobre un título pobre | sobre título + descripción reales |
| Servicio / categoría | a ciegas | con contexto |
| Datos faltantes (folio, serie…) | nunca se piden | se pueden pedir antes de crear |

**Consecuencia:** el asesor abre un ticket "no me funciona" sin contexto, con
prioridad media aunque el cliente esté caído, y tiene que leer todo el chat.

---

## 2. Alcance

**Dentro (Fase 1):**
1. Paso de **intake IA** que lee la conversación y devuelve los campos del
   ticket ya armados (título, descripción, kind, impacto, urgencia, tipo,
   servicio, categoría).
2. **Directiva parametrizable**: `@crear_ticket(prioridad=alta, tipo=Soporte)`.
3. El **prompt complementario manda**: sus reglas en lenguaje natural se pasan
   al intake como política de negocio.
4. Confirmación al cliente con **folio real** (no `#id`).
5. **Deflexión antes de crear** (ext. novedosa): si KB/Discourse resuelve con
   confianza, responde y **no** crea el ticket. Ver §11.1.
6. **Anti-duplicado en vivo** (ext. novedosa): si el contacto ya tiene un caso
   abierto del mismo tema, **vincula/actualiza** en vez de duplicar. Ver §11.2.
7. **Score de riesgo → prioridad dinámica** (ext. novedosa): sentimiento +
   reincidencia + señales de fuga ajustan la prioridad y marcan riesgo. Ver §11.3.

**Dentro (Fase 2, opcional):**
8. `missing_info`: si falta un dato clave, el bot lo **pide antes** de crear
   (requiere estado de "intake en curso").

**Fuera (otro plan):**
- Crear ticket desde el User Portal ([[Plan-User-Portal]]).
- Multi-idioma del intake (por ahora español).
- Extensiones de infraestructura nueva (intake multimodal voz/imagen,
  confirmación interactiva con botones, auto-cierre + CSAT, SLA proactivo):
  fuera de Fase 1/2.

---

## 3. Diseño

### 3.1 Flujo objetivo

```
Cliente responde en el seguimiento
        │
        ▼
ContactTrackingResponseAnalyzerJob
        │   (KBase no resolvió, o el prompt manda ticketear)
        ▼
Cases::TicketCreatorService.create_if_needed
        │   1) ¿está @crear_ticket?  → parse de parámetros de la directiva
        │   2) construye contexto (últimos N msgs + datos del contacto)
        │
        ├─[§11.1 DEFLEXIÓN]─ ¿KB/Discourse resuelve con confianza?
        │        └─ sí → responde + "¿te sirvió o levanto el caso?" → NO crea
        │
        ├─[§11.2 ANTI-DUP]─ ¿el contacto ya tiene un caso abierto del tema?
        │        └─ sí → vincula/actualiza ese caso + avisa "#folio en curso" → NO crea
        │
        ▼
Cases::Ai::Intake.extract(context, policy, overrides)   ◄── NUEVO
        │   LLM → JSON saneado:
        │   { title, description, ticket_kind, impact, urgency,
        │     case_type_id, affected_service_id, category_id,
        │     confidence, missing_info[] }
        │
        ├── missing_info presente y Fase 2 activa ──► preguntar y NO crear (espera)
        │
        ▼ (campos completos)
[§11.3 SCORE DE RIESGO]  sentimiento + reincidencia + señales de fuga
        │   → ajusta prioridad (sube) y marca risk/churn en el ticket
        ▼
Cases::OrchestratorService.create_from_ai(...)          ◄── NUEVO (o extender create_for_manual)
        │   ticket ya poblado; prioridad por matriz ITIL si no vino explícita
        ▼
Cases::RuleEngineService.evaluate!  (ruteo por tipo/categoría, igual que hoy)
        ▼
Confirmación al cliente con ticket.folio
```

### 3.2 El servicio nuevo: `Cases::Ai::Intake`

Hermano de `Cases::Ai::Classifier`, reusa `Cases::Ai::BaseService#chat(json: true)`.
Diferencias clave con el clasificador actual:

- **Lee la conversación**, no solo un título.
- Genera **título y descripción** (redacción), además de clasificar.
- Recibe la **política del prompt complementario** como instrucciones.
- Elige tipo/servicio/categoría **de las listas reales de la cuenta** (por id),
  igual que hoy hace `Classifier#sanitize` (no inventa ids).

Contrato de salida (JSON saneado):

```jsonc
{
  "title":               "Portal de facturación no carga desde el martes",
  "description":         "El cliente reporta que al entrar a Facturación ve pantalla en blanco desde el 21/07. Ya limpió caché sin éxito. Usa Chrome.",
  "ticket_kind":         "incident",          // enum válido o null
  "impact":              "high",              // low|medium|high o null
  "urgency":             "high",
  "case_type_id":        1,                   // id real de la cuenta o null
  "affected_service_id": 4,                   // id real o null
  "category_id":         12,                  // id real o null
  "confidence":          0.82,
  "missing_info":        []                   // p.ej. ["folio de factura"]
}
```

Prioridad: **no** la pide al LLM. Si vienen `impact` + `urgency`, la deriva la
matriz ITIL existente (`Cases::PriorityMatrix`, ya la usa el modelo en
`derive_priority_from_matrix`). Si la directiva trae `prioridad=…`, gana esa.

### 3.3 Directiva parametrizable

Mismo patrón que `@buscar_foro(nombre_fuente)` (ya se parsea con regex). Ejemplos:

```
@crear_ticket
@crear_ticket(prioridad=alta)
@crear_ticket(tipo=Soporte, prioridad=urgente)
@crear_ticket(area=facturación)
```

Regla de precedencia de cada campo:

```
directiva explícita  >  reglas del prompt (intake)  >  inferencia IA  >  default
```

Parámetros soportados (Fase 1): `prioridad`, `tipo` (nombre → id). El resto se
deja a la IA. `tipo` se resuelve por nombre contra `account.case_types`
(case-insensitive); si no existe, se ignora y cae a la inferencia.

---

## 4. Cambios por archivo (touchpoints)

> Sketches ilustrativos, **no** el código final.

| Archivo | Cambio |
|---|---|
| `app/services/cases/ai/intake.rb` | **Nuevo.** `extract(conversation:, policy:, overrides:)` → Hash saneado. |
| `app/services/cases/ticket_creator_service.rb` | Parsear `@crear_ticket(...)`; construir contexto; llamar al Intake; pasar campos al Orchestrator; usar `folio` en la confirmación. |
| `app/services/cases/orchestrator_service.rb` | `create_from_ai(...)` (o extender `create_for_manual`) que acepte los campos ya resueltos y respete la matriz de prioridad. |
| `app/jobs/contact_tracking_response_analyzer_job.rb` | Sin cambios de flujo (ya llama a `TicketCreatorService`); a lo sumo pasar `recent_messages`. |
| `app/services/cases/ai/base_service.rb` | Reuso tal cual (`chat(json: true)`). |
| `EditTemplate.vue:418` | Actualizar el label/ayuda de la directiva y (opcional) documentar los parámetros en el picker. |
| i18n (si se toca UI de ayuda) | Texto de la directiva parametrizable. |

Parsing de la directiva (boceto):

```ruby
DIRECTIVE_RE = /@crear_ticket(?:\(([^)]*)\))?/i

def directive_overrides
  m = @tracking.complementary_prompt.to_s.match(DIRECTIVE_RE)
  return {} unless m
  (m[1] || '').split(',').each_with_object({}) do |pair, h|
    k, v = pair.split('=', 2).map { |s| s.to_s.strip }
    h[k.downcase] = v if k.present? && v.present?
  end
  # => { "prioridad" => "alta", "tipo" => "Soporte" }
end
```

Política para el intake = el prompt complementario **sin** las directivas
técnicas (se limpia como ya se hace con `@agendar_calendar`/kbase en el job).

---

## 5. El prompt complementario (cómo lo usa el usuario)

La gracia: el mismo texto que hoy es decorativo pasa a **gobernar** el intake.

```
Eres el asistente de soporte de ACME. Resuelve dudas con la información
disponible. Si el cliente reporta una falla o pide algo que requiere a una
persona, levanta un ticket con @crear_ticket(prioridad=alta) cuando esté
caído o sin servicio; si no, @crear_ticket normal.

Al armar el ticket:
- Título: frase clara del problema, no el mensaje literal.
- Descripción: resume qué pasa, desde cuándo y qué intentó el cliente.
- Tipo: "Incidente" si algo dejó de funcionar; "Solicitud" si pide alta/cambio.
- Si no menciona el número de cliente, pídelo antes de crear el ticket.

Confirma con el folio y avisa que un asesor lo contactará.
```

- Las líneas "Al armar el ticket…" van al **system del Intake** como reglas.
- "pídelo antes de crear" activa el camino `missing_info` (Fase 2).

---

## 6. `missing_info` — pedir el dato antes de crear (Fase 2)

El reto es **estado**: al preguntar, el ticket aún no existe, y el siguiente
mensaje del cliente debe entrar como "respuesta al intake", no como nuevo caso.

```
Intake → missing_info: ["número de cliente"]
        │
        ▼
Bot pregunta: "Para levantar tu caso, ¿me compartes tu número de cliente?"
        │   marca tracking.pending_intake = { asked_at, needs: [...] }  (Redis o columna)
        ▼
Cliente responde con el dato
        │
        ▼
Intake reintenta con el contexto ampliado → crea el ticket
```

Alcance mínimo Fase 2: **un solo turno** de repregunta (si tras preguntar sigue
sin el dato, crea igual y lo marca en `missing_info` del ticket para el asesor).
Evita bucles.

---

## 7. Configuración / gating

- Reusar el flag de IA de la cuenta: `CaseAiConfig.for_account(account).active?(:classify)`
  (ya gobierna la clasificación). Se puede añadir `active?(:intake)` si se quiere
  separar, pero de inicio conviene colgarlo del mismo permiso para no multiplicar
  toggles.
- Si el intake IA está apagado o falla → **degradar** al comportamiento actual
  (título recortado + clasificación async). Nunca dejar de crear el ticket por
  un fallo del LLM.

---

## 8. Riesgos y trampas

- ⚠️ **Costo/latencia**: es una llamada LLM extra por ticket. Mitiga: solo
  corre cuando `@crear_ticket` está presente y KBase no resolvió (bajo volumen).
- ⚠️ **IDs inventados**: el LLM puede devolver un `case_type_id`/`category_id`
  inexistente. Sanear contra las listas reales (como `Classifier#sanitize`).
- ⚠️ **Prioridad doble**: si la directiva trae `prioridad=` y además hay
  impacto+urgencia, respetar la directiva y **no** dejar que la matriz la pise
  (hoy `derive_priority_from_matrix` corre en `before_validation`: hay que
  saltarla cuando la prioridad vino explícita).
- ⚠️ **Confirmación con `#id`**: el texto actual dice `caso ##{ticket.id}`; el
  cliente debe ver el **folio** (`ticket.folio`).
- ⚠️ **Loop de repregunta** (Fase 2): limitar a un turno.
- ⚠️ **Idempotencia**: `find_active_ticket` ya evita duplicar si hay uno activo
  del contacto; mantener esa guardia antes del intake para no gastar LLM.

---

## 9. Pasos de implementación (orden sugerido)

**Fase 1**
1. `Cases::Ai::Intake` + saneo (sin tocar el flujo todavía; test unitario con
   una conversación de ejemplo).
2. `Orchestrator.create_from_ai` (o extender `create_for_manual`) respetando la
   matriz de prioridad y la precedencia de campos.
3. `TicketCreatorService`: parseo de la directiva + intake + confirmación con
   folio + degradación a lo actual si IA off/falla.
4. Gate de **deflexión** (§11.1) y de **anti-duplicado** (§11.2) antes del intake.
5. **Score de riesgo** (§11.3) entre el intake y la creación.
6. Ajuste del label/ayuda de la directiva en `EditTemplate.vue`.

**Fase 2**
7. `pending_intake` + repregunta de un turno (`missing_info`, §6).

**Cierre**
8. Verificación end-to-end en un seguimiento real (WhatsApp): incidente caído,
   solicitud simple, uno con dato faltante, uno deflectado por KB, uno duplicado.

---

## 10. Criterios de aceptación

- Un mensaje "el portal está caído desde ayer" genera un ticket con **título
  redactado**, **descripción-resumen**, tipo "Incidente" y prioridad **alta**
  (no media).
- `@crear_ticket(prioridad=urgente)` fuerza urgente aunque la IA opine otra cosa.
- Con la IA apagada, sigue creando el ticket como hoy (sin romper).
- La confirmación al cliente muestra el **folio**.
- Si KB resuelve con confianza, **no** se crea ticket (deflexión) — §11.1.
- Un segundo mensaje del mismo contacto sobre el mismo tema **no** duplica el
  caso: lo vincula/actualiza — §11.2.
- Un mensaje con sentimiento muy negativo + palabra de fuga sube la prioridad y
  marca el ticket como riesgo — §11.3.
- (Fase 2) Si el prompt pide un dato y falta, el bot lo pide una vez antes de crear.

---

## 11. Extensiones novedosas (dentro de Fase 1/2)

Las tres se enganchan en el paso de intake y **reutilizan servicios que ya
existen**. No requieren infraestructura nueva.

### 11.1 Deflexión antes de crear (resolver > ticketear)

Antes de armar el ticket, consulta KB/Discourse; si hay respuesta confiable,
responde y ofrece **no** abrir el caso.

```
@crear_ticket detectado
      │
      ▼
KnowledgeBaseResponseService (confianza ≥ umbral)
      ├─ sí → responde la solución + "¿te sirvió, o levanto el caso?"
      │        └─ cliente dice "no me sirvió" → sigue al intake y crea
      └─ no → sigue al intake
```

- *Reusa*: `KnowledgeBaseResponseService` (ya corre antes en el job; aquí se
  vuelve **gate explícito con umbral de confianza**).
- *Config*: umbral por cuenta; si el prompt trae `@crear_ticket(forzar=si)`,
  se salta la deflexión.
- *Utilidad*: menos tickets basura; el caso solo nace cuando de verdad hace falta.

### 11.2 Anti-duplicado en vivo (un cliente = un caso, cross-canal)

Si el contacto ya tiene un caso **abierto** del mismo tema, no se duplica.

```
Intake produce {title, description}
      │
      ▼
Cases::Ai::DuplicateDetector (contra tickets abiertos del contacto)
      ├─ match → vincula el mensaje al caso existente + comenta en su timeline
      │           + avisa al cliente "ya tienes el caso #folio en curso"  → NO crea
      └─ sin match → crea normal
```

- *Reusa*: `Cases::Ai::DuplicateDetector` (ya existe, hoy no está enganchado en
  este flujo) + `find_active_ticket` del Orchestrator como primera guardia barata.
- *Utilidad*: evita 3 tickets del mismo problema porque el cliente escribió por
  WhatsApp, correo y web.

### 11.3 Score de riesgo → prioridad dinámica

La prioridad no sale solo de impacto×urgencia: se ajusta con **señales del
contacto**.

| Señal | Fuente (ya existe) | Efecto |
|---|---|---|
| Sentimiento muy negativo | `save_sentiment_analysis` | +1 nivel de prioridad |
| Reincidencia (varios tickets recientes) | historial del contacto | +1 nivel |
| Palabras de fuga ("cancelo", "me voy") | intake (lista/LLM) | marca `churn_risk` + sube a alta |

```
prioridad_base (matriz ITIL o directiva)
      │  + ajustes por señales (con techo en "urgent")
      ▼
prioridad_final  +  etiqueta de riesgo en el ticket (visible para el asesor)
```

- *Reusa*: sentimiento que ya guardas + conteo de tickets del contacto.
- *Regla*: la directiva explícita (`prioridad=`) **siempre gana**; el score solo
  ajusta cuando la prioridad no vino forzada.
- *Utilidad*: alerta temprana de churn/escalación, no solo triage técnico.

> Fuera de estas tres (y por tanto fuera de Fase 1/2): intake multimodal
> (voz/imagen), confirmación interactiva con botones, auto-cierre + CSAT y SLA
> proactivo. Se documentarán en un plan aparte si se retoman.
