---
titulo: Servicios y jobs — Contact Tracking
tipo: diseno
tags: [contact-tracking, servicios, jobs, sidekiq]
---

# Servicios y jobs

## Servicios (`app/services/contact_trackings/` + raíz)

### `ContactTrackings::RouterService` — `router_service.rb`
Clasifica la **intención** del mensaje del contacto dentro de un tracking activo
(GPT-4o-mini, salida JSON). Rutas posibles:

| Ruta | Significado |
|---|---|
| `:rejected` | rechaza la oferta |
| `:interested` | interesado (sin cita concreta) |
| `:reschedule` | pide cambiar fecha/hora (extrae datos) |
| `:book_appointment` | pide cita/reunión → ver `AvailabilitySlotService` |
| `:kbase` | pregunta técnica → Base de Conocimiento (`kbase_available`) |
| `:botseller` | comando para bot de ventas (`botseller_available`) |
| `:tracking` | conversación normal (fallback) |

Controlado por env `TRACKING_DETECT_INTENT` (ver [[API-y-rutas]]).

### `ContactTrackings::BulkAssignService` — `bulk_assign_service.rb`
Asigna una `tracking_template` a contactos resueltos por un filtro. **Reutiliza
`Contacts::FilterService`** (mismo `payload`). Límite `MAX_BULK_ASSIGN = 30`. Opciones
`excluded_contact_ids`, `skip_active`. Devuelve `{ inserted, skipped, errors }`.
Detalle → [[Bulk-assign]].

### `ContactTrackingImportService` — `app/services/contact_tracking_import_service.rb`
Importa trackings desde XLSX/CSV (parser nativo). `MAX_IMPORT_ROWS = 50`. Crea
contactos si no existen, normaliza teléfono a E.164. Detalle → [[Importacion-excel-csv]].

### `ContactTrackings::KeywordActionService` — `keyword_action_service.rb`
Evalúa si el contenido de un mensaje coincide con un `keyword_action` configurado y
ejecuta la acción (**cancel** o **pause**). Match exacto, case-insensitive,
word-boundary (no substring). Acción **silenciosa** (no responde al contacto).
`VALID_ACTIONS = %w[cancel pause]`, `VALID_DIRECTIONS = %w[incoming outgoing both]`.

### `ContactTrackings::AvailabilitySlotService` — `availability_slot_service.rb`
(`proyecto@bot_seguimiento_calendar`) Calcula slots libres consultando
`UserCalendarIntegration` por `calendar_integration_ids`. Defaults: horario 9–18,
5 días hábiles, máx 5 slots, duración 30 min. Usado en la ruta `:book_appointment`.

## Jobs (`app/jobs/`)

### `ContactTrackingJob` — `contact_tracking_job.rb` (v3.0.0)
Ejecución individual de un tracking en su `scheduled_for`. Queue `scheduled_jobs`.
Lógica de envío según **ventana WhatsApp de 24 h** (`whatsapp_window_open?`):

1. WA + ventana **cerrada** + sin plantilla → **error** (`last_error`).
2. WA + ventana cerrada + con plantilla → enviar **solo la plantilla**.
3. WA + ventana **abierta** → mensaje **generado por IA** (ignora plantillas).
4. Otros canales → mensaje IA normal.

Protege con **lock pesimista** y **dedup** (ignora si el último intento fue hace <60 s).

### `ContactTrackings::ExecutePendingJob` — `contact_trackings/execute_pending_job.rb`
**Cron cada 5 min** (`*/5 * * * *`, queue `scheduled_jobs`). Busca trackings con
`scheduled_for <= now` en estados activos y encola un `ContactTrackingJob` por cada uno.
Es el motor real de programación (respaldo de los callbacks del modelo).

### `ContactTrackingResponseAnalyzerJob` — `contact_tracking_response_analyzer_job.rb`
Analiza la respuesta **entrante** del contacto: sentimiento (`last_sentiment_analysis`)
y dispara el `RouterService`; también evalúa `keyword_actions` entrantes.

### `ContactTrackings::KeywordCheckerJob` — `contact_trackings/keyword_checker_job.rb`
Evalúa `keyword_actions` en mensajes **salientes**. Se dispara desde
`Message.after_create_commit :check_keyword_actions_for_outgoing`. (Las entrantes las
ve el ResponseAnalyzer.)

### `ContactTrackings::CleanupJob` — `contact_trackings/cleanup_job.rb`
Limpia trackings terminales antiguos (>90 días).

> Nota: existe también `app/jobs/contact_trackings.rb` (archivo suelto, revisar antes
> de tocar — no confundir con el namespace `contact_trackings/`).
