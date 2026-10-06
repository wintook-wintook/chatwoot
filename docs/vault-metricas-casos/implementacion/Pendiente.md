---
titulo: Pendiente — Métricas de Casos (Informes → Oportunidades)
tipo: implementación
tags: [metricas-casos, informes, oportunidades, pendiente, todo]
---

# Pendiente — Métricas de Casos (Informes → Oportunidades)

Rama `feat/metricas_casos`. Seguimiento de oportunidades de venta sobre el módulo
de Casos (`CaseTicket`), agregado como una nueva sección del menú de **Informes**
("Oportunidades"), sin tocar el módulo de Gestor de Tickets.

## ✅ Ya implementado y verificado (backend + frontend + 88 tests)

Todo vive bajo `V2::Reports::Cases::*` (`app/builders/v2/reports/cases/`),
controller `Api::V2::Accounts::CaseReportsController`
(`app/controllers/api/v2/accounts/case_reports_controller.rb`), rutas bajo
`/api/v2/accounts/:account_id/case_reports/*`, y una sola página
`OpportunityReports.vue` (menú Informes → Oportunidades) que muestra todo junto:

- **#1 Embudo** — cantidad de casos por columna del Kanban del Tipo de Caso elegido
  (o por `status` canónico si no se elige tipo). `DistributionBuilder#funnel`.
- **#2 Ganados/perdidos** — `open/won/lost/other_closed` + tasa de conversión.
  `DistributionBuilder#outcome`.
- **#3 Ranking de vendedores** — mismo cálculo de #2 reagrupado por `assignee_id`,
  más promedio de días hasta el cierre. `AssigneeSummaryBuilder`.
- **#5 Nuevas vs. cerradas** — serie temporal por `created_at`/`closed_at`,
  agrupable por día/semana/mes. `TimeseriesBuilder`.
- **#4 Velocidad por etapa** — promedio de días en cada `status`, reconstruido
  desde el historial de `case_events` (no desde columnas del Kanban — ver nota
  abajo). `StageDurationBuilder#velocity`.
- **#6 Oportunidades estancadas** — mismo builder, lista las abiertas cuyo tiempo
  en el status actual supera un umbral configurable. `StageDurationBuilder#stalled`.

**Nota de diseño importante (#4/#6):** se armó sobre `status` canónico, NO sobre
`case_type_column_id`, porque `move_across_state` (mover un ticket cruzando de
estado) actualiza el puntero de columna en silencio, sin crear un evento
`column_changed` — solo `move_within_state` (misma etapa, distinta columna) lo
registra. Reconstruir "tiempo por columna" con los datos actuales tendría huecos
reales. Decisión tomada con el usuario en esta rama.

## Pendiente

- [ ] **#8 Motivos de pérdida** — top de `closure_cause` cuando
      `closure_type: cancelled`. Reusa `DistributionBuilder` (mismo shape
      group+count que `#funnel`/`#outcome`): agregar un método al builder + acción
      y ruta `loss_reasons` al controller, más el consumo en el frontend
      (`caseReports.js`, store, tabla en `OpportunityReports.vue`). El más rápido
      de los dos — no requiere ninguna decisión de producto nueva.
- [ ] **#7 Valor de pipeline** — suma de un campo numérico (monto estimado) por
      etapa/vendedor. **Bloqueado por una decisión de producto:** ¿ya existe un
      `CaseTypeField` de tipo `number` pensado para esto en algún Tipo de Caso, o
      hay que pedir que se configure uno primero? El valor viajaría en
      `case_tickets.custom_attributes` (jsonb), bajo la clave del campo
      correspondiente. Sin ese campo configurado el reporte quedaría armado pero
      sin datos que mostrar.

## 🔗 Relacionado
- Módulo base (Kanban por tipo, `CaseTicket`, `case_events`):
  `docs/vault-tickets/implementacion/Historial-de-implementacion.md`,
  `docs/vault-tickets/implementacion/Plan-Columnas-Por-Tipo.md`.
- Motor de Informes stock (no-Cases, para comparar patrones):
  `app/builders/v2/reports/conversations/`.
