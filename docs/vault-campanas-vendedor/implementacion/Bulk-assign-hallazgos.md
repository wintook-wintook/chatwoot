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
1. ✅ **RESUELTO** — *Corría síncrono en el request.* Ahora `#call` solo valida + crea la
   `TrackingCampaign` + encola `ContactTrackings::BulkAssignJob` (queue `medium`); el loop por
   contacto (`#process!`) corre en background. El request responde de inmediato con
   `{ queued, campaign_id, campaign_name }` y el progreso se ve en el detalle de la campaña.
2. ✅ **RESUELTO** — *Inbox inferido.* El inbox queda **fijado por la campaña** (= inbox de la
   plantilla). `#call` exige que la plantilla tenga inbox; `resolve_inbox_and_conversation` solo
   reusa una conversación si es **del mismo inbox**, si no abre una nueva en ese canal
   ([[Modelo-de-datos]]).
3. 🟠 **Límite 100, sin cola/paginación** (el doc viejo decía 30; el código dice **100**).
4. 🟡 **`insert!` saltea validaciones/callbacks** — encola el job a mano; el índice único se
   maneja por excepción (no upsert) → en concurrencia, error genérico.
5. 🟡 **Sin agrupador** — cada bulk es un disparo suelto; falta `TrackingCampaign` para medir.
6. 🟡 **Efecto colateral** — crea N conversaciones + notas privadas (dispara listeners/notifs).

## Conclusión
Para el módulo de campañas, el bulk necesitaba: **(a) job en background ✅, (b) inbox fijo de la
campaña ✅, (c) agrupar bajo `TrackingCampaign` ✅**. Los tres ya están. Queda pendiente subir el
límite de 100 con cola/paginación (#3) y la deuda menor de `insert!`/efectos colaterales (#4, #6).
Cae en [[Fases]] F2/F3.
