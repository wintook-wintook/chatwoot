---
titulo: Pendiente
tipo: implementacion
tags: [campanas-vendedor, pendiente, todo]
---

# Pendiente

## Decisiones abiertas (resolver antes de F1)
- [ ] **Objetivo de campaña**: ¿enum fijo (cotizar/agendar demo/vender/reactivar) o libre?
- [ ] **Score IA**: ¿qué lo alimenta (intención + sentimiento + señales de compra)? ¿se
      recalcula por mensaje o al cerrar la conversación?
- [ ] **"Valor generado"**: ¿lo declara el vendedor, lo infiere la IA del texto, o viene del
      ERP/cotización (enlazable a Cobranza-ERP a futuro)?
- [ ] **Oportunidad automática**: ¿crear tarjeta en el **Kanban** al detectar interés alto?
- [ ] **Límite de prospectos**: hoy bulk = 100. Para campañas reales subir (¿200? ¿sin límite con cola?).
- [ ] **Autonomía**: criterio exacto de "resuelto por IA".
- [ ] **Multicanal**: 1 tracking activo por (contacto, inbox) — la campaña fija su inbox.

## TODOs de implementación (cuando se apruebe)
- [ ] Mover `BulkAssignService` a job en background ([[Bulk-assign-hallazgos]] #1).
- [ ] Fijar inbox de la campaña en lugar de inferirlo ([[Bulk-assign-hallazgos]] #2).
- [ ] Crear `TrackingCampaign` + `TrackingCampaignProspect` ([[Modelo-de-datos]]).
- [ ] Extender el analyzer para setear score/interés/resultado/valor ([[KPIs]]).
- [ ] Las 7 vistas + i18n es/en ([[Las-7-vistas]]).

> Plan fuente completo: `docs/campanas_agente_vendedor_plan.md`.
