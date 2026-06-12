---
titulo: API y rutas — Contact Tracking
tipo: diseno
tags: [contact-tracking, api, rutas, env]
---

# API y rutas

`config/routes.rb` (bloques marcados `proyecto@contact_tracking v2.0`,
`proyecto@bulk_tracking_assign`, etc.). Controllers en
`app/controllers/api/v1/accounts/`.

## Endpoints anidados bajo contacto

```
GET    /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings
GET    .../contact_trackings/:id
POST   .../contact_trackings              body: { contact_tracking: { objective, scheduled_for, inbox_id, ... } }
PATCH  .../contact_trackings/:id
DELETE .../contact_trackings/:id

# member
POST   .../contact_trackings/:id/pause
POST   .../contact_trackings/:id/resume
POST   .../contact_trackings/:id/cancel
# collection
POST   .../contact_trackings/improve_text   # mejorar texto con IA
```
Controller: `contact_trackings_controller.rb`.

## Endpoints top-level (por cuenta)

```
resources :tracking_templates, only: [index, show, create, update, destroy]   # tracking_templates_controller.rb
POST /api/v1/accounts/:account_id/contact_tracking_imports                     # contact_tracking_imports_controller.rb
POST /api/v1/accounts/:account_id/contact_tracking_bulk_assigns               # contact_tracking_bulk_assigns_controller.rb
```

- **bulk_assigns** params: `payload` (filtro tipo `Contacts::FilterService`),
  `template_id`, `scheduled_for`, `excluded_contact_ids`, `skip_active`. Delega a
  `BulkAssignService` (límite 30). Ver [[Bulk-assign]].
- **imports** params: archivo XLSX/CSV. Delega a `ContactTrackingImportService`
  (límite 50). Ver [[Importacion-excel-csv]].

## Variables de entorno

| Env | Efecto |
|---|---|
| `TRACKING_DETECT_INTENT` | `true` activa el `RouterService` (clasificación de intención). |
| (OpenAI) | la API key sale de la **integración OpenAI de la cuenta** (no env propia del módulo). |

> **No hay feature flag** en `config/features.yml` para este módulo: está siempre
> activo. Si se necesitara gating por cuenta, habría que agregar la flag (ver
> [[Pendiente]]).
