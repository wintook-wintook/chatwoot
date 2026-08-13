# Plan de reorganización de `contact_tracking_response_analyzer_job.rb`

> **Estado: PENDIENTE — no ejecutar sin confirmación explícita del usuario.**
> El usuario pidió guardar este plan para revisarlo y avisará cuándo se ejecuta.

## Diagnóstico

`app/jobs/contact_tracking_response_analyzer_job.rb` — 1893 líneas, 95 métodos en una sola clase.
Ya tiene secciones delimitadas por comentarios `# ====`, pero son solo visuales. El bloque más
grande ("Handler: Agendar cita via Google Calendar", líneas 742-1503, ~760 líneas) mezcla 6
responsabilidades distintas sin separación real: booking, negociación de horario, email,
confirmación, cancelación.

## Por qué es seguro reorganizar

No hay ivars compartidos entre métodos — los `@algo` que aparecen en el archivo son en realidad
tags de comentario `proyecto@...`, no variables de instancia reales. Todo se pasa explícito por
parámetros (`tracking`, `message`, `timezone`). Esto lo confirmó el trabajo de
[[bug-dia-semana-equivocado]].

## Estrategia

Clases plain en `app/services/contact_trackings/` (no concerns de Rails) — mismo patrón que ya
usan `router_service.rb` y `availability_slot_service.rb`.

## Mapa de reorganización

| Nuevo archivo | Métodos | Líneas origen aprox. |
|---|---|---|
| Job orquestador (queda, se achica a ~150 líneas) | `perform`, `process_message_for_tracking`, `try_kbase_then_conversational`, `appointment_dispatchable?`, `classify_appointment`, `dispatch_appointment_action`, `appointment_state_summary`, `router_current_date`, `classify_route`, `kbase_available?`, `find_active_trackings`, `already_replied_by_bot?` | 47-410 |
| `ContactTrackings::ConversationalReplyService` | `generate_and_send_conversational_reply`, `generate_conversational_reply`, `conversational_fallback`, `generate_action_reply`, `build_action_prompt`, `default_reply`, `call_openai_for_reply` | 413-491, 1506-1600 |
| `ContactTrackings::IntentHandlers` | `handle_rejected`, `handle_interested`, `handle_reschedule`, `handle_followup_reschedule` | 496-583 |
| `ContactTrackings::CalendarConfigService` | `agendar_calendar_directive?`, `calendar_configured?`, `appointment_timezone`, `google_calendar_timezone`, `appointment_timezone_calendar_id`, `appointment_calendar_ids`, `slot_service_for`, `working_hours_for`, `handle_no_calendar_configured` | 284-333, 661-682, 706-725 |
| `ContactTrackings::AppointmentBookingService` | `dispatch_book_appointment`, `handle_book_appointment`, `requested_datetime_for_booking`, `booking_search_anchor`, `try_book_requested_slot`, `inform_existing_appointment`, `format_appointment_datetime`, `ticket_directive_present?` | 726-861 |
| `ContactTrackings::AppointmentMoveService` | `handle_move_appointment`, `reschedule_move_has_time?`, `ask_move_when`, `try_move_to_exact_slot`, `offer_move_alternatives`, `move_target_time` | 584-660, 692-705 |
| `ContactTrackings::SlotNegotiationService` | `pending_slot_selection?`, `handle_slot_selection`, `proceed_with_selected_slot`, `try_kbase_during_negotiation`, `handle_slot_negotiation`, `parse_requested_datetime`, `extract_datetime_json`, `looks_like_datetime_proposal?`, `looks_like_quantity?`, `parse_slot_choice`, `clear_pending_slot` (+ `DATETIME_PROPOSAL_HINT`) — acá vive el fix de [[bug-dia-semana-equivocado]] | 861-1136 |
| `ContactTrackings::EmailCollectionService` | `pending_email_selection?`, `prompt_for_email`, `handle_pending_email`, `clear_pending_email` | 1137-1201 |
| `ContactTrackings::AppointmentConfirmationService` | `confirm_and_create_appointment`, `create_or_move_calendar_event`, `delete_stale_appointment_event`, `slot_payload` | 683-691, 1202-1326 |
| `ContactTrackings::AppointmentCancellationService` | `handle_cancel_appointment` | 1327-1377 |
| `ContactTrackings::SlotFormatter` | `slots_presentation_for`, `format_slots_lines`, `slot_calendar_label`, `order_slots_for_presentation`, `slot_date_range_text`, `format_slots_detailed/simple/by_agent/by_calendar/by_day`, `timezone_label`, `format_slots_message`, `offer_slots` (+ `SLOT_DAY_NAMES`, `SLOT_MONTH_NAMES`) | 1378-1502 |
| `ContactTrackings::NotificationService` | `save_sentiment_analysis`, `send_auto_reply`, `resolve_attachment_directives`, `bot_user`, `create_private_note`, `notify_admin_interested` | 1604-1730 |
| `ContactTrackings::AiContextUtils` | `get_api_key`, `get_recent_context`, `get_tracking_message_history`, `message_has_content?`, `message_text_for_ai`, `get_template_content` | 1735-1830 |
| `ContactTrackings::DateMath` | `calculate_reschedule_datetime`, `resolve_reschedule_date`, `weekday_to_date` — ya casi módulo puro, reusable también por `router_service.rb` | 1834-1893 |

## Trade-off

Trabajo mecánico pero extenso (14 archivos nuevos, ~95 llamadas a reubicar). Cada extracción
debería ir con al menos una prueba de humo del flujo real (`rails runner` contra una conversación
real, como en [[bug-dia-semana-equivocado]]) antes de dar por buena esa sección.

## Próximo paso acordado

Empezar por `SlotNegotiationService` para validar el patrón antes de ir por el resto — **pero solo
cuando el usuario lo confirme**.

## Relacionado
- [[bug-dia-semana-equivocado]]
- [[bot-seguimientos-openai]]
