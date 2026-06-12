---
titulo: Asignación masiva (Bulk assign) — Contact Tracking
tipo: implementacion
tags: [contact-tracking, bulk, filtros]
---

# Asignación masiva (Bulk assign)

Asignar una `tracking_template` ("Agente IA") + fecha a **un conjunto de contactos
resueltos por el filtro/segmento/etiqueta activos**. Commit `8cae85fd` (11-jun-2026).

## Backend — `ContactTrackings::BulkAssignService`

`app/services/contact_trackings/bulk_assign_service.rb`

- Resuelve contactos **reutilizando `Contacts::FilterService`**:
  ```ruby
  ::Contacts::FilterService.new(@account, @current_user,
    { 'payload' => @filter_payload }.with_indifferent_access).perform
  ```
- `MAX_BULK_ASSIGN = 30` (límite de seguridad por asignación).
- Opciones: `excluded_contact_ids`, `skip_active` (omite contactos con tracking activo).
- Copia del template al tracking: `objective`, `ai_context`, `retry_interval_*`,
  `whatsapp_templates`, `keyword_actions`, `calendar_*`, etc. (con defaults a 30).
- Devuelve `{ inserted: N, skipped: N, errors: [...] }`.

## API

`POST /api/v1/accounts/:account_id/contact_tracking_bulk_assigns`
(`contact_tracking_bulk_assigns_controller.rb`). Params: `payload`, `template_id`,
`scheduled_for`, `excluded_contact_ids`, `skip_active`.

## Frontend — flujo

`components/contacts/BulkTrackingAssign/` + `routes/dashboard/contacts/`:

1. Usuario aplica un filtro/segmento/label en la vista de contactos.
2. `Header.vue` muestra botón **"Asignar Agente IA"** → abre `BulkAssignModal`.
3. Selecciona **plantilla** + **fecha/hora** de inicio.
4. "Revisar contactos" → `ReviewContactsModal` (paginado, permite excluir).
5. Confirmar → `api/contactTrackingBulkAssigns.js` → endpoint.
6. Muestra resumen `inserted / skipped / errors`.

i18n: `i18n/locale/{es,en}/bulkTrackingAssign.json`
(`BULK_TRACKING_ASSIGN.MODAL.*`).
