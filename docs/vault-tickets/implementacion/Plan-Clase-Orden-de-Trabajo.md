---
titulo: Plan — Clase «Orden de trabajo»
tipo: implementación
fase: F1–F3
tags: [tickets, plan, orden-de-trabajo, clase-de-caso]
---

# Plan — Clase «Orden de trabajo»

Rama `feat/nva_oportunidad`. Flag `case_work_order` (al final de `features.yml`). Continúa
[[Plan-Casos-Hoja-de-ruta]] (E4). Reutiliza lo de [[Plan-Clase-Comercial]]: tipos con columnas,
tareas, reuniones + Google Calendar, relaciones entre casos y la clase fija (E1.4).

## Idea
Trabajo **planeado** (Soporte es reactivo y se mide por SLA): fecha programada, técnico,
dirección, horas, materiales, checklist y conformidad del cliente. Se mide por **cumplimiento**.
Elementos: **«Órdenes»**. Color `#0d9488` (verde azulado).

## Capacidades por clase (`CaseType::CLASS_CAPABILITIES`)
En lugar de preguntar «¿es Comercial?» por el código, cada clase declara lo que hace:

| Clase | `sla` | `portal` | `bot_status` |
|---|---|---|---|
| Soporte (y sin tipo) | ✅ | ✅ | ✅ |
| Comercial | — | — | — |
| Orden de trabajo | — | — | ✅ |
| Proyecto (reservado) | — | — | — |

- `sla` → metas de SLA (`assign_sla_targets`), monitor de SLA y cierre automático de resueltos,
  Métricas de Soporte (`metrics`, `by_type`). Front: `classHasSla` (aviso de SLA, punto del folio,
  SLA/nivel/escalamiento en la ficha y en la tarjeta del Tablero).
- `portal` → tipo público (si no, `public` se apaga solo) y consulta por folio en el portal.
- `bot_status` → el bot `@estado_ticket`.
- Scope `CaseTicket.with_capability(:x)` (subconsulta, ver [[Trampas]] #21); `#class_capability?`.

## Fases
| Fase | Contenido | Estado |
|---|---|---|
| F1 | Flag, clase ofrecida, flujo de columnas, capacidades por clase, Lista/Tablero/Tipos, textos | ✅ 2026-10-20 |
| F2a | Datos de la orden (dirección, horas est./real, facturable) + materiales; formulario y panel; cierre con conformidad | ✅ 2026-10-20 |
| F2b | «Programar visita» (reuniones); «Crear orden» desde ticket / oportunidad ganada; combo, filtros y columnas de la Lista | ✅ 2026-10-20 |
| F3 | Métricas (cumplimiento de fecha, horas real vs estimado, retrabajos, por técnico) + specs | ✅ 2026-10-20 |

## F1 — lo construido
- `features.yml`: `case_work_order` al final. `featureFlags.js`: `CASE_WORK_ORDER`.
- `case_types_controller`: `OFFERED_CLASSES` + `CLASS_FLAGS` (cada clase exige su flag).
- `CaseTypeColumn::WORK_ORDER_TEMPLATE`: Por programar (open, classified) · Programada (assigned,
  in_diagnosis) · En ejecución (in_progress, escalated) · Pausada (waiting_*) · Terminada
  (resolved, validating) · Cerrada (closed) · Cancelada (cancelled).
- Capacidades (arriba): `CaseType.classes_with`, `.class_capability?`; `CaseTicket#work_order?`.
  Reemplazan `non_commercial` en el monitor de SLA, el bot, el portal y las Métricas de Soporte
  (`non_commercial` sigue existiendo, ya sin uso en `app/`).
- Front: `CASE_CLASSES` con `work_order`; `classI18nBase`, `classHasSla`, `caseClassOfTicket`
  genérico. Lista y Tablero mandan siempre `case_class` y filtran tipos con `typesOfClass`.
  `FINE_FILTERS_BY_CLASS.work_order`. `ClassMetrics`: aviso «llegan en la F3». Tipos: columna y
  filtro de clase con las clases activas; modal de tipo ofrece la clase con su flag.
- i18n `CASE_TICKETS.CLASSES.WORK_ORDER`, `TYPES.CLASS.FILTER.WORK_ORDER`, `TYPES.CLASS.HELP`.
- Specs: `spec/models/case_work_order_class_spec.rb` (5) + helper/rutas (front).
- Una «Terminada» no se cierra sola (no tiene `sla`): espera la conformidad.

## Decisiones (2026-10-20, las recomendadas)
1. Conformidad = nombre de quien recibe + nota (la firma dibujada, después).
2. Materiales = concepto, cantidad, unidad y costo unitario **opcional**.
3. Técnico = el asignado (+ su equipo).
4. Horas reales = a mano (en la orden o al cerrar).
5. Cliente = opcional (orden interna sin cliente).
6. El cliente la ve en el bot `@estado_ticket`; en el portal no.

## F2a — lo construido
- Migración `20261024160000_add_work_order_to_case_tickets`: en `case_tickets` work_address,
  estimated_hours / actual_hours (6,2), billable (default false), received_by, received_at,
  conformity_note; tabla `case_work_order_items` (descripción, cantidad > 0, unidad, unit_cost
  opcional, posición; FK cascade al caso).
- `CaseWorkOrderItem` (#total = cantidad × costo; solo en un caso de clase orden).
- `CaseTicket`: `WORK_ORDER_FIELDS`, `assign_work_order_data` + `log_work_order_change!`
  (`CaseEvent work_order_changed: 39`), `work_order_total`, dirección sin espacios sobrantes.
  **Cierre** (`closed`): `validate_conformity!` pide horas reales (o las ya capturadas) y quién
  recibió; `conformity_attrs` guarda received_at = ahora. Reabrir borra la conformidad (las
  horas se quedan). «Terminada» (resolved) no pide nada.
- API: alta (con cliente o interna) y edición aceptan los datos; `closure` acepta
  actual_hours/received_by/conformity_note; JSON `is_work_order`, datos, `work_order_items`,
  `work_order_total`; `case_tickets/:id/work_order_items` (create/update/destroy, cerrada =
  solo lectura); el lote no cierra órdenes (`needs_own_closure?`).
- Front: `helper/caseWorkOrder.js`; bloque de la orden en `CaseTicketInternalModal` (alta/edición)
  y `CaseTicketModal`; `workOrder/WorkOrderPanel.vue` en la ficha (datos en línea, materiales con
  importe y total en la moneda de la cuenta, conformidad al cerrar); el modal de cierre de la
  ficha pide la conformidad en una orden. El Tablero manda a la ficha para cerrar (como Soporte).
- Specs: `spec/requests/api/v1/accounts/case_work_orders_spec.rb` (9) + `caseWorkOrder.spec.js`.

## F2b — lo construido
- **Visitas** = reuniones del caso (`case_meetings`, Google Calendar). «Programar visita» en el
  panel abre el alta de reunión precargada (`MeetingFormModal` prop `defaults`: título
  «Visita · …», lugar = dirección, organizador = el técnico si puede serlo).
  `CaseMeeting after_create_commit` → `CaseTicket#mark_visit_scheduled!`: una orden «Por
  programar» (open/classified) pasa a «Programada» (assigned, motivo «Visita programada»); si ya
  avanzó no se toca. `next_visit_at` (próxima vigente) y `visit_overdue?` (vigente con hora pasada)
  en el JSON; el panel los muestra. Reprogramar/cancelar solo cambia la próxima visita (la orden
  no regresa sola a «Por programar»).
- **Crear orden desde otro caso**: `POST case_tickets/:id/work_order { case_type_id }` →
  `Cases::WorkOrderFromCaseService` (flag activo, tipo de clase orden, origen Soporte/sin tipo u
  oportunidad **ganada**). Hereda cliente, conversación, asunto y descripción (sin cliente = orden
  interna); relación `work_order_origin: 5` (al final del enum) + evento `related` en los dos casos.
  Botón «Crear orden de trabajo» en la ficha (modal para elegir el tipo).
- **Lista de Órdenes**: combo de etapa `WORK_ORDER_STAGES` (Abiertas · Por programar · Programadas ·
  En ejecución · Pausadas · Terminadas · Cerradas · Canceladas · Todas; default Abiertas) →
  `statuses=a,b` (nuevo parámetro del index) o `status=pending`; se guarda por clase y en las vistas
  (`stage`). Filtros finos `visit` (hoy / esta semana / vencida → `visit_from`/`visit_to`,
  `visit_overdue`) y `billable`. Columnas: Técnico, Etapa (columna del tipo), Horas (real / est. +
  punto «Facturable») y Próxima visita (o «Visita vencida» en rojo).
- Specs: 6 casos más en `case_work_orders_spec.rb` (15) + helper de filtros.

## F3 — lo construido
- `V2::Reports::Cases::WorkOrderBuilder` + `GET /api/v2/accounts/:id/case_reports/work_orders`
  (filtros de siempre: tipo, técnico, equipo, `since`/`until`). Solo clase Orden de trabajo.
  - **Abierto** (foto de hoy): abiertas (pendientes + terminadas sin conformidad), por programar,
    por conformidad, visitas vencidas (solo pendientes, igual que el filtro de la Lista), y abiertas
    por etapa = la columna que pinta el Tablero (la guardada si cubre el estado, si no la primera del
    tipo que lo cubre).
  - **Terminado** (resolved_at o closed_at en el rango): **cumplimiento** = terminada a más tardar el
    día de su última visita (programada/reprogramada/realizada); «tarde» si después; «sin visita»
    si nunca se agendó (no entra al %). Horas real vs estimado (solo órdenes con los dos) y desvío %;
    retrabajos = `reopen_count > 0`; facturables y suma de sus materiales con costo; canceladas
    (por `updated_at`, no hay fecha propia de cancelación).
  - Por técnico y por tipo: abiertas, terminadas, % a tiempo, horas, desvío, retrabajos.
- Front `workOrder/WorkOrderMetrics.vue` (vía `ClassMetrics`): KPIs, barras de una serie en el
  color de la clase (etapas y puntualidad, con etiqueta directa, tooltip y vista de tabla) y tablas
  por técnico y por tipo; recuerda tipo, período, técnico y equipo por clase.
- Spec: `spec/builders/v2/reports/cases/work_order_builder_spec.rb` (4).

## 🔗 Relacionado
[[00-Indice]] · [[Plan-Casos-Hoja-de-ruta]] · [[Plan-Clase-Comercial]] · [[Trampas]]
