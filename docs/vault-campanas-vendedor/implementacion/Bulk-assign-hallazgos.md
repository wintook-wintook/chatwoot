---
titulo: Bulk assign — hallazgos de la revisión
tipo: implementacion
tags: [campanas-vendedor, bulk-assign, revision]
---

# Bulk assign — hallazgos (revisión 2026-06-29)

Servicio: `app/services/contact_trackings/bulk_assign_service.rb`
(`ContactTrackings::BulkAssignService`). Endpoint
`POST .../contact_tracking_bulk_assigns`. Es el **Paso 3–4** del módulo.

## ✅ Bien
- Reusa `Contacts::FilterService` (mismos filtros/segmentos/etiquetas).
- `skip_active` respeta **1 activo por (contacto, inbox)**.
- Errores por contacto (no rompe el lote): `{ inserted, skipped, errors[] }`.
- Soporta `excluded_contact_ids`; copia campos del template al tracking.

## ⚠️ A corregir (ordenado por impacto para campañas)
1. 🔴 **Corre SÍNCRONO en el request** — `find_each` + `insert!` + (si no hay conversación)
   crea conversación + nota privada por contacto. Con `MAX_BULK_ASSIGN = 100` → riesgo de
   **timeout**. Para campañas (1000 prospectos): **mover a job en background**.
2. 🟠 **Inbox inferido** — `resolve_inbox_and_conversation` toma la conversación más reciente
   de **cualquier** inbox → el prospecto puede caer en el **canal equivocado**. La campaña debe
   **fijar el inbox** ([[Modelo-de-datos]]).
3. 🟠 **Límite 100, sin cola/paginación** (el doc viejo decía 30; el código dice **100**).
4. 🟡 **`insert!` saltea validaciones/callbacks** — encola el job a mano; el índice único se
   maneja por excepción (no upsert) → en concurrencia, error genérico.
5. 🟡 **Sin agrupador** — cada bulk es un disparo suelto; falta `TrackingCampaign` para medir.
6. 🟡 **Efecto colateral** — crea N conversaciones + notas privadas (dispara listeners/notifs).

## Conclusión
Para el módulo de campañas, el bulk necesita: **(a) job en background, (b) inbox fijo de la
campaña, (c) agrupar bajo `TrackingCampaign`**. Cae en [[Fases]] F2/F3.
