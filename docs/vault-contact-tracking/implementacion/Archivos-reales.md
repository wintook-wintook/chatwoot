---
titulo: Archivos reales — Contact Tracking
tipo: implementacion
tags: [contact-tracking, archivos, mapa]
---

# Archivos reales

Mapa de rutas construidas (verificado en la rama `dashboard_contact_tracking`).
El módulo evoluciona: ante la duda, `grep -rn "proyecto@contact_tracking" app/`.

## Backend

```
app/models/
  contact_tracking.rb                # modelo principal v2.0.0 (schema annotado en cabecera)
  tracking_template.rb               # plantillas ("Agentes IA")

app/services/
  contact_tracking_import_service.rb # importación XLSX/CSV (límite 50)
  contact_trackings/
    router_service.rb                # clasificación de intención (GPT-4o-mini)
    bulk_assign_service.rb           # asignación masiva (límite 30, usa Contacts::FilterService)
    keyword_action_service.rb        # acciones cancel/pause por palabra clave
    availability_slot_service.rb     # slots de calendario (proyecto@bot_seguimiento_calendar)

app/controllers/api/v1/accounts/
  contact_trackings_controller.rb            # CRUD + pause/resume/cancel + improve_text
  contact_tracking_bulk_assigns_controller.rb
  contact_tracking_imports_controller.rb
  tracking_templates_controller.rb

app/jobs/
  contact_tracking_job.rb                    # ejecución individual v3.0.0 (ventana WA 24h, lock, dedup)
  contact_tracking_response_analyzer_job.rb  # sentimiento + router (entrantes)
  contact_trackings.rb                       # (archivo suelto — revisar antes de tocar)
  contact_trackings/
    execute_pending_job.rb                   # cron */5 — encola pendientes
    keyword_checker_job.rb                   # keyword_actions salientes
    cleanup_job.rb                           # limpieza >90 días

db/migrate/                                  # ver lista en [[Modelo-de-datos]]
config/routes.rb                             # ver [[API-y-rutas]]
```

## Frontend (`app/javascript/dashboard/`)

```
api/
  contactTrackings.js  contactTrackingBulkAssigns.js
  trackingTemplates.js contactTrackingImports.js

store/modules/
  contactTrackings.js  trackingTemplates.js

components/contacts/ContactTracking/
  TrackingForm.vue  TrackingList.vue  ContactTrackingModal.vue
  CancelTrackingModal.vue  ResumeTrackingModal.vue
  KeywordActionsEditor.vue  TemplatePreview.vue  TrackingTemplates.vue

components/contacts/BulkTrackingAssign/
  BulkAssignModal.vue  ReviewContactsModal.vue

routes/dashboard/contacts/
  ContactsView.vue  Header.vue            # botón "Asignar Agente IA"

routes/dashboard/settings/trackingTemplates/
  Index.vue  EditTemplate.vue  ImportModal.vue  trackingTemplates.routes.js

helper/trackingHelpers.js
composables/useTrackingForm.js
i18n/locale/{es,en}/  contactTracking.js  bulkTrackingAssign.json  trackingTemplates.json
```
