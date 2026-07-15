---
titulo: Modelo de datos — Contact Tracking
tipo: diseno
tags: [contact-tracking, datos, migraciones]
---

# Modelo de datos

Dos tablas: `contact_trackings` (instancias de seguimiento) y `tracking_templates`
(plantillas reutilizables = "Agentes IA"). Ver ciclo de vida en [[Ciclo-de-vida]].

## Tabla `contact_trackings`

`app/models/contact_tracking.rb` — modelo v2.0.0. Schema annotado en la cabecera del
archivo (fuente de verdad). Columnas relevantes:

| Columna | Tipo | Notas |
|---|---|---|
| `contact_id` | bigint FK | requerido |
| `conversation_id` | bigint FK | opcional |
| `inbox_id` | bigint FK | requerido (canal de ejecución) |
| `account_id` | bigint FK | requerido |
| `tracking_template_id` | integer FK | opcional (si vino de plantilla) |
| `objective` | string | **not null** — qué busca el seguimiento |
| `scheduled_for` | datetime | **not null, indexed** — próxima ejecución |
| `status` | string | default `pending` — 7 estados, ver [[Ciclo-de-vida]] |
| `max_attempts` / `attempt_count` | integer | default 3 / 0 |
| `retry_interval_value` / `retry_interval_unit` | integer / string | default 30 / `minutes` (`minutes`/`hours`/`days`) |
| `ai_context` / `complementary_prompt` | text | contexto e instrucciones para la IA |
| `whatsapp_templates` | json | nombres de plantilla WA por intento |
| `keyword_actions` | jsonb (not null) | `[{keyword, action: cancel\|pause, direction: incoming\|outgoing\|both}]` |
| `calendar_integration_ids` | jsonb (not null) | IDs de `UserCalendarIntegration` para agendar |
| `calendar_event_duration` | integer | default 30 min |
| `last_sentiment_analysis` | jsonb | análisis del último mensaje (indexado por `->>'sentiment'`) |
| `appointment_at` | datetime (index) | cita agendada — Fase 0 del Dashboard de Seguimientos |
| `last_intent` | string (index) | última intención (espejo de `last_sentiment_analysis->>'sentiment'`) |
| `outcome` | string | resultado del seguimiento: `appointment`/`interested`/`rejected`/… |
| `response_adjustments_count` | integer | repeticiones en modo auto-retry |
| `last_attempt_at` / `last_message_sent` / `last_error` | datetime/text/string | telemetría del último intento |
| `paused_at` | datetime | cuándo se pausó |
| `quote_id` | integer | cotización asociada (si aplica) |

### Índices clave

- `index_unique_active_tracking_per_contact_inbox` — **UNIQUE parcial** sobre
  `(contact_id, inbox_id, status)` para `pending/scheduled/active/paused` ⇒ **1 activo por
  `(contacto, inbox)`** (permite paralelo en canales distintos; ver [[Seguimiento-por-canal]]).
- `index_contact_trackings_on_status_and_scheduled_for` — para el cron de pendientes.
- `index_contact_trackings_on_sentiment` — expresión sobre `last_sentiment_analysis->>'sentiment'`.

## Tabla `tracking_templates`

`app/models/tracking_template.rb` — plantillas reutilizables ("Agentes IA"). Campos:
`name` (único por cuenta), `objective`, `ai_context`, `complementary_prompt`,
`retry_interval_value/unit`, `whatsapp_templates`, `keyword_actions`,
`calendar_integration_ids`, `calendar_event_duration`, `inbox_id`, `user_id`,
`kbase_hook_id` (gancho a Base de Conocimiento). Origen de la asignación masiva y la
importación.

## Migraciones (orden cronológico)

Tabla principal consolidada + adiciones incrementales:

- `20260206120000_create_contact_trackings_consolidated.rb`
- `20260213150000_create_tracking_templates.rb` (+ `*_add_inbox_id`, `*_add_user_id`)
- `20260422000000_add_retry_interval_to_tracking_templates.rb`
- `20260428100000/100001_add_keyword_actions_to_*` (templates y trackings)
- `20260507100000_add_kbase_hook_id_to_tracking_templates.rb`
- `20260520000001/000002_add_calendar_*_to_tracking_templates.rb`
- `20260527182109_add_calendar_integration_ids_to_contact_trackings.rb`
- `20260602183336_add_calendar_event_duration_to_contact_trackings.rb`
- `20260603162748_add_tracking_template_id_to_contact_trackings.rb`

> El schema annotado en la cabecera de `contact_tracking.rb` es la referencia viva;
> si algo aquí difiere, gana el modelo.
