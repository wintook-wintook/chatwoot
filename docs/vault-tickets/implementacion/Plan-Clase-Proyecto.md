---
titulo: Plan — Clase «Proyecto»
tipo: implementación
fase: P1–P3
tags: [tickets, plan, proyecto, clase-de-caso]
---

# Plan — Clase «Proyecto»

Rama `feat/nva_oportunidad`. Flag `case_project` (al final de `features.yml`). Continúa
[[Plan-Casos-Hoja-de-ruta]] (E5). Reutiliza las capacidades por clase, la plantilla de columnas,
las relaciones, las tareas y el patrón de [[Plan-Clase-Orden-de-Trabajo]].

## Idea
Trabajo **grande y por fases**, con fecha objetivo y presupuesto, que **agrupa** órdenes de
trabajo y tickets. Suele nacer de una oportunidad ganada. Se mide por avance contra plan y horas
contra presupuesto. Elementos: **«Proyectos»**. Color `#6366f1` (índigo).

## Decisiones (2026-10-20)
1. Avance **automático** (casos hijos + hitos terminados); a mano mientras no tenga hijos.
2. Presupuesto = **horas + monto opcional** (moneda de la cuenta, en `currency`).
3. Hijos = **órdenes de trabajo y tickets de Soporte** (no oportunidades).
4. Hitos = **tareas con la casilla «Hito»**.
5. Cliente **opcional** (proyecto interno).
6. El cliente lo ve en el bot `@estado_ticket` (`bot_status`); en el portal no.

## Fases
| Fase | Contenido | Estado |
|---|---|---|
| P1 | Flag, clase, fases, datos (inicio, objetivo, presupuesto, avance), pestaña «Proyecto», formulario, Lista (combo de fases, columnas, aviso «Atrasados»), Tablero | ✅ 2026-10-20 |
| P2 | Casos hijos (relación nueva, crear/ligar orden o ticket, pestaña «Casos del proyecto»), hitos (tareas «Hito»), avance automático, horas reales = suma de las órdenes hijas, «Crear proyecto» desde oportunidad ganada | ✅ 2026-10-20 |
| P3 | Línea de tiempo (hitos e hijos por fecha, hoy y objetivo) + métricas (en tiempo / en riesgo / atrasados, horas vs presupuesto, hitos vencidos, por responsable) | ✅ 2026-10-20 |

## P1 — lo construido
- `CaseType::CLASS_CAPABILITIES['project'] = [:bot_status]`; `case_types_controller` lo ofrece con
  su flag. `CaseTypeColumn::PROJECT_TEMPLATE`: Planeación (open, classified, assigned, in_diagnosis)
  · Ejecución (in_progress, escalated) · Pausado (waiting_*) · Entrega (resolved, validating) ·
  Cerrado · Cancelado.
- Migración `20261021170000_add_project_to_case_tickets`: project_start_on, project_due_on,
  budget_hours (8,2), budget_amount (14,2), progress (0–100) + índice parcial de la fecha objetivo.
- `CaseTicket`: `PROJECT_FIELDS`, `project?`, `project_overdue?` (abierto con objetivo pasado),
  `assign_project_data` + `log_project_change!` (`CaseEvent project_changed: 40`), objetivo ≥ inicio,
  moneda de la cuenta al crear. **Cierre** sin causa/solución: resumen opcional en `closure_solution`.
- API: alta/edición con los datos (`project:` en el orquestador), JSON (`is_project`, datos,
  `project_overdue`), filtro `project_due_from/to`, aviso `alert_count` = atrasados.
- Front: `helper/caseProject.js`; `CASE_CLASSES` + `CASE_PROJECT`; fases genéricas
  (`CLASS_STAGES`, `stageToParams(stage, clase)`), filtro fino `due`, aviso «Atrasados (n)»;
  `project/ProjectPanel.vue` en la pestaña «Proyecto» de la ficha; bloque índigo en los formularios;
  Lista con Fecha objetivo, Avance y Fase; tarjeta del Tablero con fecha objetivo y avance; modal de
  cierre con resumen. Métricas: aviso «llegan en P3».
- Specs: `spec/requests/api/v1/accounts/case_projects_spec.rb` (4) + `caseProject.spec.js`.

## P2 — lo construido
- `CaseTicketRelation`: `project_member: 6` (hijo → proyecto) y `project_origin: 7` (proyecto →
  oportunidad), al final del enum. `CaseTicket::PROJECT_CHILD_CLASSES` = orden + Soporte;
  `#project_children`, `#parent_project` (un proyecto por caso).
- **Avance automático** `#project_progress_summary`: (hijos terminados — resolved/validating/closed —
  + hitos hechos) / (hijos no cancelados + hitos); sin hijos ni hitos manda `progress` (a mano).
  Horas reales = suma de `actual_hours` de sus órdenes. JSON: `progress` (efectivo),
  `progress_manual`, `project_summary`.
- Migración `20261021180000_add_milestone_to_case_tasks` (`case_tasks.milestone`). La API de tareas
  lo acepta y lo devuelve.
- `CaseProjectChildrenController` (`case_tickets/:id/project_children`): index, create (crear orden o
  ticket dentro —hereda el cliente— o ligar uno existente con `ticket_id`), destroy (lo saca, no lo
  borra). Proyecto cerrado = no se agregan. Evento `related` en los dos casos.
- `Cases::CaseFromCaseService` (antes `WorkOrderFromCaseService`) generalizado por destino:
  orden (`work_order_origin`) o proyecto (`project_origin`, solo desde oportunidad ganada).
  `POST case_tickets/:id/project`.
- Front: `project/ProjectChildren.vue` (pestaña «Casos del proyecto»: lista con clase, estado,
  responsable, visita/horas o vencimiento; crear, ligar con buscador, quitar). `ProjectPanel`: avance
  automático («n de m casos e hitos»), casos/hitos hechos, horas reales contra presupuesto (rojo si
  pasa de 100 %); el campo de avance se oculta en automático. Tareas: casilla «Hito» y etiqueta en la
  tabla (solo en proyectos); guardar una tarea refresca el avance. «Crear proyecto» en una oportunidad
  ganada (el mismo modal que «Crear orden de trabajo»).
- Specs: `case_projects_spec.rb` (10 en total, 6 nuevos).

## P3 — lo construido
- **Línea de tiempo**: `GET case_tickets/:id/project_children/timeline` → inicio (o alta), objetivo,
  hoy y los elementos con fecha (hito por su vencimiento; orden por su próxima visita o vencimiento;
  ticket por su vencimiento), con `done` / `overdue`. `project/ProjectTimeline.vue` en la pestaña
  «Proyecto»: pista con «Hoy» (línea sólida) y objetivo (línea punteada), hitos = rombo, casos =
  círculo; estado por forma + color + texto; leyenda; lista ordenada debajo (vista accesible).
  Clic en un caso → su ficha.
- **Métricas** `V2::Reports::Cases::ProjectBuilder` + `GET /api/v2/.../case_reports/projects`:
  salud de los abiertos (atrasado = objetivo pasado; en riesgo = avance > 20 pts detrás del % de
  plazo transcurrido; en tiempo; sin fechas), abiertos por fase (la columna del Tablero), hitos
  vencidos, horas reales (de las órdenes) contra presupuesto y pasados de presupuesto; terminados en
  el período con entrega a tiempo (≤ fecha objetivo). Por responsable y por tipo.
  `project/ProjectMetrics.vue` vía `ClassMetrics`.
- Specs: `project_builder_spec.rb` (3) + 1 de línea de tiempo en `case_projects_spec.rb`.

## 🔗 Relacionado
[[00-Indice]] · [[Plan-Casos-Hoja-de-ruta]] · [[Plan-Clase-Orden-de-Trabajo]] · [[Trampas]]
