---
titulo: Frontend — Contact Tracking
tipo: diseno
tags: [contact-tracking, frontend, vue, vuex]
---

# Frontend (Vue + Vuex)

Todo bajo `app/javascript/dashboard/`. Rutas exactas en [[Archivos-reales]].

## API clients (`api/`)

| Archivo | Cubre |
|---|---|
| `contactTrackings.js` | CRUD individual + `pause`/`resume`/`cancel` + `improveText` |
| `contactTrackingBulkAssigns.js` | asignación masiva por filtro |
| `trackingTemplates.js` | CRUD de plantillas |
| `contactTrackingImports.js` | subida Excel/CSV |

## Vuex stores (`store/modules/`)

- **`contactTrackings.js`** — `records` keyed por id, `uiFlags`; getters
  `getTrackings(contactId)` / `getTrackingById(id)`; actions `fetch/create/update/
  pause/resume/cancel/improveText`. Obtiene `accountId` de `currentChat` con fallback
  a `getCurrentAccountId`.
- **`trackingTemplates.js`** — `records` (array), getters
  `getTemplates/getTemplateById/getTemplatesByTag/getAllTags/getAllInboxIds`; actions
  `get/create/update/delete`.

## Componentes (`components/contacts/`)

`ContactTracking/`:
- `TrackingForm.vue` — crear/editar tracking
- `TrackingList.vue` — lista con filtros (estado, búsqueda)
- `ContactTrackingModal.vue` — modal contenedor del widget
- `CancelTrackingModal.vue` / `ResumeTrackingModal.vue` — confirmaciones
- `KeywordActionsEditor.vue` — editor de `keyword_actions`
- `TemplatePreview.vue` — preview de plantilla aplicada
- `TrackingTemplates.vue` — selector de plantilla

`BulkTrackingAssign/` (commit `8cae85fd`):
- `BulkAssignModal.vue` — modal principal de asignación masiva
- `ReviewContactsModal.vue` — revisar/excluir contactos antes de confirmar

## Settings (`routes/dashboard/settings/trackingTemplates/`)

- `Index.vue` — listado de plantillas
- `EditTemplate.vue` — crear/editar plantilla (grande, ~35 KB)
- `ImportModal.vue` — importación Excel/CSV
- `trackingTemplates.routes.js` — rutas de la sección

## Puntos de entrada en contactos (`routes/dashboard/contacts/`)

- `ContactsView.vue` — importa `BulkAssignModal`, controla `showBulkAssignModal`.
- `Header.vue` — botón **"Asignar Agente IA"** (visible en contexto de filtro/segmento/label).

## Helpers / composables / i18n

- `helper/trackingHelpers.js` — formateo de fechas, tiempo restante, conversión de
  intervalos, `getStatusClass/getStatusLabel`, `canCancel/canEdit/canDuplicate`,
  `getMinDateTime`.
- `composables/useTrackingForm.js` — lógica compartida de formularios.
- i18n en `i18n/locale/{es,en}/`: `contactTracking.js`, `bulkTrackingAssign.json`,
  `trackingTemplates.json`.
