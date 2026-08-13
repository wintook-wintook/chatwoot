# Cambios de comportamiento del bot — 20 abril 2026

## `app/jobs/contact_tracking_job.rb`
**Respaldo:** `contact_tracking_job.rb.bak_20260420_163842`

**Cambio:** cuando la ventana WhatsApp de 24h está **abierta**, la IA ya no usa el contenido de la
plantilla WhatsApp como base para generar el mensaje. Genera el mensaje libremente con IA pura.

- Antes (Caso 3): ventana abierta + tiene plantilla → obtenía texto de la plantilla y lo pasaba a
  OpenAI como base.
- Después (Caso 3): ventana abierta → siempre genera con IA pura, sin importar si hay plantillas
  configuradas. Las plantillas WhatsApp solo se usan cuando la ventana está **cerrada** (Caso 2).

**Why:** las plantillas son para cuando no se puede enviar mensaje libre (ventana cerrada). Dentro
de ventana, la IA debe ser libre de generar el mejor mensaje según el contexto.

## `app/jobs/contact_tracking_response_analyzer_job.rb`
**Respaldo:** `contact_tracking_response_analyzer_job.rb.bak_20260420_170433`

**Cambio 1:** `find_active_trackings` ahora incluye seguimientos en estado `paused`.
```ruby
# Antes: .active_or_scheduled  (solo: active, scheduled, pending)
# Después:
.where(status: %w[active scheduled pending paused])
```
**Why:** cuando un seguimiento está pausado, el bot debe seguir respondiendo mensajes del cliente
(preguntas, reagendamientos, rechazos). El scope `active_or_scheduled` del modelo no se tocó para
no afectar `due_for_execution`.

**Cambio 2:** intenciones `question`, `out_of_context` y `unclear` desactivadas en
`apply_sentiment_decision`.

| Intención | Estado |
|---|---|
| `rejected` | ✅ Activa |
| `interested` | ✅ Activa |
| `reschedule` | ✅ Activa |
| `unclear` | ❌ Desactivada (ignorada con log) |
| `question` | ❌ Desactivada (ignorada con log) |
| `out_of_context` | ❌ Desactivada (ignorada con log) |

**How to apply:** para reactivar cualquier intención, quitar el `return` en el `case` de
`apply_sentiment_decision` y restaurar la llamada al handler correspondiente. Los handlers
(`handle_question`, `handle_unclear`, `handle_out_of_context`) están intactos en el código.

## Relacionado
- [[bot-seguimientos-openai]]
- [[bug-dia-semana-equivocado]]
