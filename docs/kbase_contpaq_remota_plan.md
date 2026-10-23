# Base de Conocimiento remota de CONTPAQi — Agente de Servicio

**Rama:** `feat/kbase_contpaq_remota` (sale de `develop`, base `67bd3d28`)
**Estado:** solo plan — no hay código escrito
**Fecha:** 2026-09-03

Integrar el **Agente de Servicio CONTPAQi** (API remota vía Azure API Management) como
una fuente más de la Base de Conocimiento, direccionable desde el Entrenamiento de un
Agente IA y utilizable dentro de una rama `@ruta`.

---

## 1. El hallazgo que define el diseño

Todas las fuentes actuales devuelven **contexto**, y el contexto lo redacta OpenAI.
Esta API devuelve la **respuesta ya redactada**: hace la búsqueda, reordena la evidencia
y escribe, todo del otro lado.

```
FUENTES ACTUALES (@discourse, @buscar_foro, pgvector, {{doc:}}…)

   pregunta ──> search_X() ──> contexto ──> ask_openai_with_history() ──> answer
                                              (nuestro prompt, temp 0.0)      │
                                                                    footer ◄──┘
                                                              (fuente atribuida)

CONTPAQi — Agente de Servicio

   pregunta ──> POST /answer ──> { answer, sources[], message_id }
                                     │         │           │
                             ya redactada   footer    para feedback
```

**Consecuencia:** no pasa por `ask_openai_with_history`. Si le diéramos su `answer` a
OpenAI para "responder", lo haríamos reescribir una respuesta ya fiel a su documentación
— justo lo que `7a7ff21a` acaba de arreglar en la otra dirección.

El precedente correcto es `perform_erp_query` (`knowledge_base_response_service.rb:217`),
la rama de `{{consulta:}}`: compone y llama a `send_reply` sin pasar por el modelo.

```
detect_directive ──> case directive[:mode]          (:65)
                       ├─ :erp_query          ──> perform_erp_query      ← sin OpenAI
                       ├─ :canned_response    ──> perform_pgvector
                       ├─ :knowledge_source   ──> perform_discourse
                       ├─ :discourse_integration ──> perform_discourse_integration
                       └─ :contpaq_support    ──> perform_contpaq        ← NUEVO, sin OpenAI
```

**Lo que se pierde a propósito:** el `complementary_prompt` del agente (tono, regla de
evidencia, no diagnosticar) **no aplica** a esta rama, porque no somos nosotros quienes
redactamos. Es una diferencia real de comportamiento respecto de las demás ramas y hay
que decirla en la guía de autoría, no descubrirla en producción.

---

## 2. Contrato de la API

```
Base   https://devapimintern.azure-api.net/agente-servicio/v1
Auth   OAuth2 client_credentials contra Microsoft Entra External ID
       token 1 hora · SIN refresh token · Authorization: Bearer <jwt>

GET  /ping                 sin token — health check
POST /answer               {question, user_id, conversation_id?, images?}
                             -> {answer, sources:[{title, source_url}], message_id}
POST /feedback/message     {message_id, rating, user_id, comments?}
                             -> {status:"ok", feedback_action:"recorded"}
```

### Límites (todos devuelven error, no truncan)

| Límite | Valor | Falla |
|---|---|---|
| Llamadas | **60/min por integrador**, compartido entre procesos | 429 |
| `question` | 8 000 caracteres | 422 |
| `conversation_id` | 128, charset `A-Z a-z 0-9 . _ : -` | 422 |
| `user_id` | 256 | 422 |
| `comments` | 4 000 | 422 |
| Cuerpo | 1 MB | 413 |
| Token | 1 hora | 401 |

El límite es **por integrador, no por IP**: el contador se comparte entre todos los
procesos que usen las mismas credenciales. Un contador en memoria por worker de Sidekiq
no sirve.

---

## 3. `user_id` — identidad del contacto

Obligatorio, y validado como correo electrónico o RFC mexicano. Se sintetiza un correo
en el dominio `kontrolya.com`:

```
┌─ contact.phone_number presente? ──── SÍ ──> últimos 10 dígitos del E.164, sin '+'
│                                             +523121122345 -> 3121122345@kontrolya.com
│
└─ NO ──> <contact_id>_<account_id a 4 dígitos>@kontrolya.com
          /app/accounts/2/contacts/15783 -> 15783_0002@kontrolya.com
```

`phone_number` ya está validado como E.164 en `contact.rb:52` (`/\+[1-9]\d{1,14}\z/`),
así que "los últimos 10 dígitos" está bien definido.

**Casos a cubrir:**
- Número de menos de 10 dígitos (E.164 admite desde 2): `.last(10)` devuelve el número
  entero. Aceptable, pero el resultado deja de ser de 10 dígitos — no asumir el ancho.
- Sin conversación ni contacto (no debería ocurrir en este flujo): sin `user_id` no se
  consulta; se registra y se devuelve `false`.

> El ancho de 4 dígitos del `account_id` se tomó del ejemplo (`2` → `0002`). Si una
> cuenta supera 9999 el identificador crece; no rompe nada porque el tope es 256.

---

## 4. `conversation_id` — memoria del lado del servidor

Su sola presencia activa la memoria en el servicio. Como el servicio ya recuerda el hilo,
**esta rama no arma historial propio** (`kb_history`) ni lo envía.

Charset permitido: `A-Z a-z 0-9 . _ : -`. La documentación marca esto como **la causa más
frecuente de un 422 inesperado**, así que se sanea siempre en vez de confiar:

```
"acct-#{account_id}-conv-#{conversation.display_id}"   →  gsub(/[^A-Za-z0-9._:-]/, '-').first(128)
```

Usar `display_id` y no `id` mantiene el identificador estable y legible para soporte,
que es lo que hay que citar al reportar un problema.

---

## 5. Los tres 200 que no son respuesta

Llegan con **HTTP 200**. Tratarlos como error sería un bug:

| Situación | Qué hacer |
|---|---|
| **Falta especificar el producto** — aplica a varios productos CONTPAQi | Mostrar la aclaración y **enviar el turno siguiente con el mismo `conversation_id`**. Es el caso que exige memoria. |
| **Fuera de alcance** o intento de desviar al asistente | Mostrar el rechazo tal cual. |
| **Saludo / conversación social** | Mostrar el saludo breve. |

> ⚠️ **Corrección posterior a la implementación (2026-09-04).** Este plan daba por hecho
> que los tres llegaban con `sources` **vacío** y que por eso nunca llevarían footer.
> Medido contra el servicio real, **eso solo se cumple en un hilo nuevo**:
>
> ```
> A) hilo nuevo,  "¿Cómo genero una póliza?"          → sources = 0   ✔ como se creía
> B) mismo hilo:  1º "¿Cómo timbro la nómina…?"       → sources = 5
>                 2º "¿Cómo genero una póliza?"       → sources = 5   ✘
> ```
>
> En B2 la respuesta es literalmente «¿De qué producto de CONTPAQi® hablas?» y venía con
> las 5 fuentes del turno **anterior**. Con la regla original le colgábamos un
> `📚 Más información:` que apuntaba a otro tema — justo lo que se quería evitar.
>
> **Resuelto cambiando el texto de la firma a `📚 Documentación relacionada:`**, que es
> cierto en los dos casos: las fuentes son las del hilo, no las de esa respuesta. Sigue
> sin haber footer cuando `sources` viene vacío.

El footer solo se arma cuando hay fuentes, mismo criterio que ya rige en
`build_sources_footer`.

`source_url` viene como **cadena vacía, nunca `null`**, cuando el documento no tiene URL
pública: una fuente con `source_url` vacío se cita por título o no se cita, pero no
produce un link roto.

---

## 6. Errores y reintentos

```
429, 500, 503  ──> reintentar con backoff exponencial
401            ──> renovar token y reintentar UNA vez; si persiste, faltan permisos
                   (rol API.ReadWrite en la aplicación)
404, 413, 422  ──> NO reintentar: la petición está mal
```

El cliente debe tolerar **dos formas de error** distintas:

```json
{"message": "Token JWT inválido, expirado o ausente"}                  // 401, del gateway
{"detail": [{"loc":["body","question"], "msg":"Field required"}]}      // 422, del servicio
{"detail": "Request body too large."}                                  // 413, del servicio
```

Toda la rama es **fail-soft**, como el resto del motor: cualquier fallo registra y
devuelve `false` (el turno sigue al conversacional), nunca revienta la conversación.

---

## 7. Dónde viven las credenciales

**Nunca en el repositorio.** La colección de Postman trae el `clientSecret` real en texto
plano y su propia documentación lo prohíbe expresamente.

> ⚠️ El secreto de la colección entregada quedó expuesto fuera de Postman. Tratarlo como
> comprometido y **rotarlo en Entra** antes de producción.

Van en el `config` jsonb de un `knowledge_source`, el mismo patrón que `discourse`
(`source.config` con `url` / `api_key` / `username`):

```
knowledge_sources
  source_type : 'contpaq_support'        ← alta en la lista de knowledge_source.rb:39
  name        : direccionable por nombre ← alta en ADDRESSABLE_BY_NAME (:35)
  config      : { base_url, token_url, client_id, client_secret, scope }
```

Sumarlo a `ADDRESSABLE_BY_NAME` fuerza la unicidad del nombre por cuenta, que es lo que
permite direccionarlo desde la directiva.

---

## 8. Directiva

```
@soporte_contpaq(NOMBRE DE LA FUENTE)
```

Entra en `KnowledgeBase::Directives.detect_search` (`directives.rb:47`) como un modo más,
y en `ready?` (`:75`) comprobando que exista la fuente activa de ese nombre. Con eso queda
usable dentro de una rama:

```
@ruta(soporte_contpaq #soporte: dudas de CONTPAQi Nóminas, Bancos, Comercial):
      @soporte_contpaq(Agente de Servicio CONTPAQi) -> @crear_ticket(tipo=Soporte)
```

**Precedencia:** la cadena de `detect_search` es un `if/elsif` donde gana la primera que
coincida. La nueva va **después** de las existentes, para no alterar el comportamiento de
ningún agente ya configurado.

`validar_entrenamiento.py` necesita la directiva en `FUENTES` y en `CONOCIDAS`; sin eso
la marca como "directiva inexistente".

---

## 9. Componentes

```
app/services/contpaq/
  token_provider.rb      client_credentials + caché en Rails.cache; renueva ANTES de expirar,
                         nunca un token por llamada. Clave por knowledge_source.
  rate_limiter.rb        60/min por integrador, contador en Redis (compartido entre procesos).
  service_agent.rb       POST /answer y POST /feedback/message; backoff, las dos formas de
                         error, un solo reintento tras renovar el token en 401.
  user_id_builder.rb     el esquema de la §3.

app/services/knowledge_base_response_service.rb
  perform_contpaq        rama nueva del case (:65); send_reply directo, sin OpenAI.

app/models/knowledge_source.rb
  'contpaq_support' en la validación (:39) y en ADDRESSABLE_BY_NAME (:35).

app/models/contpaq_message_ref.rb  (F4)
  message_id de CONTPAQi <-> mensaje de Chatwoot, para el feedback.
```

---

## 10. Fases

| | Qué | Verificación |
|---|---|---|
| **F1** | `source_type` + config de la fuente + alta en el catálogo de directivas | specs de `Directives` y `KnowledgeSource` |
| **F2** | `TokenProvider` + `RateLimiter` + `ServiceAgent` (`/ping`, `/answer`) | `/ping` en vivo; token real; los 5 casos de error de la carpeta 4 |
| **F3** | `perform_contpaq` + `user_id` + `conversation_id` saneado + los tres 200 | turno único y turno de seguimiento con memoria |
| **F4** | Feedback **backend**: persistir `message_id` y exponer el registro de la calificación | 200 `recorded`; 404 y 422 diferenciados |
| **F5** | `images` desde adjuntos del mensaje | captura real a `/answer` |
| **F6** | Documentar la rama en el manual del motor y en el validador | `validar_entrenamiento.py` acepta la directiva |

F4 es **solo backend**, por decisión: no se agrega pulgar arriba/abajo a la conversación
en esta rama.

---

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| **60/min compartido** entre todos los procesos | Limitador en Redis, no en memoria. Al agotarse: registrar y `false`, no encolar reintentos que agraven el 429. |
| El `clientSecret` entregado está expuesto | Rotarlo en Entra antes de producción. |
| Entorno **dev** (`devapimintern`) | El `base_url` es configuración de la fuente, no constante: el salto a producción no debe tocar código. |
| El agente redacta CONTPAQi, no nosotros | El `complementary_prompt` no aplica en esta rama. Documentarlo en la guía de autoría. |
| `message_id` sin conservar ⇒ feedback imposible | Es el único dato que hay que persistir de cada respuesta (F4). |
| El CI del repo no corre | Los specs se corren a mano antes del PR, como en #37/#38. |
