---
titulo: Estado actual — Contact Tracking
tipo: implementacion
tags: [contact-tracking, estado]
---

# Estado actual

Snapshot en la rama `dashboard_contact_tracking` (deriva del último `develop`).

## ✅ Completo

| Área | Detalle |
|---|---|
| Modelo de datos | `contact_trackings` + `tracking_templates` consolidados |
| CRUD básico | controller + store + componentes |
| Ciclo de vida | create → pause/resume → cancel/complete/fail ([[Ciclo-de-vida]]) |
| Reintentos | `retry_interval_*`, `max_attempts`, modo auto-retry |
| Cron + ejecución | `ExecutePendingJob` (*/5) + `ContactTrackingJob` v3 |
| WhatsApp | ventana 24 h, plantilla cuando cerrada, IA cuando abierta |
| Generación IA | GPT-4o-mini, system prompt con contexto, "mejorar texto" |
| Asignación masiva | `BulkAssignService` + UI (límite 30) ([[Bulk-assign]]) |
| Importación | XLSX/CSV nativo, E.164, límite 50 ([[Importacion-excel-csv]]) |
| Router de intención | `RouterService` (rejected/interested/reschedule/book/kbase/botseller) |
| Keyword actions | `KeywordActionService` + `KeywordCheckerJob` (out) + analyzer (in) |
| Slots de calendario | `AvailabilitySlotService` sobre `UserCalendarIntegration` |
| Concurrencia | lock pesimista + dedup <60 s + índice único 1-activo-por-contacto |
| Terminología UI | "Agente IA" alineado en i18n (es/en) + labels hardcodeados (automation, TrackingForm, EditTemplate) |

## ⚠️ Parcial / a confirmar

- **Análisis de sentimiento** — campo + índice + `ResponseAnalyzerJob` presentes;
  revisar profundidad real de la lógica y si hay vista que lo muestre.
- ~~**Agendado de citas (`:book_appointment`)**~~ — ✅ **confirmado end-to-end** (TC-04):
  propone slots (`AvailabilitySlotService`) y **crea el evento real** en Google Calendar
  (`confirm_and_create_appointment` → `GoogleCalendarService#create_event`). Limitaciones
  abiertas: mover/cancelar cita, negociación multi-turno, timezone del inbox. Ver
  [[Testeo-funcional]] y [[Pendiente]].
- **KBase / BotSeller en el router** — rutas y flags (`kbase_hook_id`,
  `kbase_available`, `botseller_available`) existen; confirmar integración real.

## ❌ No existe

- **Feature flag** del módulo (no hay entrada en `config/features.yml`).

> Mantén esta nota y [[Pendiente]] al día conforme avance la rama.
