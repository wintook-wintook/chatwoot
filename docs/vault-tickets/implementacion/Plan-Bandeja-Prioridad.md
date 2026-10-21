# Plan — Bandeja de tareas: prioridad sugerida y «Mi día»

> Rama `feat/nva_oportunidad` · iniciado 2026-10-21 · relacionado: [[Plan-Bandeja-Tareas]], [[Trampas]]

## Objetivo

Que el consultor **no tenga que pensar qué hacer primero**: la bandeja le ordena sus
pendientes por un puntaje de urgencia explicable, y él arma su día sobre ese orden.

## Decisiones (2026-10-21)

1. **El orden lo da un puntaje por reglas**, calculado en el servidor (repetible y
   explicable). La IA **solo explica** el orden (F4); nunca lo cambia.
2. **Los pesos son configurables** por cuenta (F3). Por defecto, **Proyecto pesa más que
   SLA** (proyecto atrasado 30 > SLA vencido 25).
3. **Pestañas de la bandeja:** Mías · No asignadas · Todas · **Mi día**. Se quita
   «Vencidas» (ya está en el filtro «Vence»). En «Mi día» el consultor arma su orden (F2).
4. **Duración estimada** por tarea (`case_tasks.estimated_minutes`), para sumar la carga del día.
5. **«Programada para» ≠ vencimiento** (2026-10-21). El vencimiento es el compromiso (lo pone
   quien pide); «Programada para» (`case_tasks.planned_on`, **solo fecha**) es cuándo piensa
   hacerla quien la hace. **Es lo mismo que el orden de «Mi día»**: programada para hoy = está
   en mi orden de hoy (fijar en «Mi día» = programarla para hoy). Programada para después: no
   aparece en «Mi día» (solo se cuenta). Programada para un día pasado y sin hacer: vuelve a
   «Sugeridas» con el motivo «Programada el …» (+20) y un aviso «Quedaron N sin hacer ·
   Pasarlas a hoy» (decide el agente; no se arrastran solas para no acumular).
   «Posponer a mañana» mueve la fecha programada, **nunca el vencimiento**.

## Puntaje (pesos por defecto — `Cases::TaskPriorityScore::DEFAULT_WEIGHTS`)

| Factor | Puntos |
|---|---|
| Tarea vencida | 40 + 3 por día de atraso (máx. +20) |
| Vence hoy · mañana · en 7 días | 30 · 15 · 5 |
| Prioridad de la tarea urgente · alta · media | 30 · 20 · 10 |
| Proyecto atrasado (la tarea es del proyecto o de un caso dentro de él) | 30 |
| Hito del proyecto | 10 |
| Proyecto con fecha objetivo en ≤ 7 días | 10 |
| SLA vencido · en riesgo (clases con SLA) | 25 · 15 |
| Caso urgente | 15 |
| Orden: visita vencida · visita hoy | 15 · 10 |
| Oportunidad: cierre estimado vencido o en ≤ 7 días | 10 |
| Antigüedad | 1 por día desde el alta (máx. 10) |
| Programada para un día que ya pasó y sin hacer | 20 |
| Caso en espera (cliente / tercero / interno) | −15 |

Cada factor que suma deja un **motivo** (`reasons`) que la UI muestra como etiqueta.
Las reuniones no entran al ranking (tienen hora fija): van en «Agenda de hoy».

## Fases

- **F1 — Puntaje y «Mi día».** `estimated_minutes`; servicio de puntaje; `mode=my_day` en
  `GET /case_tasks` (pendientes del agente, por puntaje, + agenda de hoy + carga del día);
  pestaña «Mi día» con la tarea siguiente destacada y los motivos; se quita «Vencidas».
- **F2 — Orden propio.** Fijar / arrastrar dentro de «Mi día» (vale por el día), aviso
  «Nueva urgente» cuando entra algo por encima de un umbral, «Posponer a mañana».
- **F3 — Pesos configurables** en Configuración → Tareas (por cuenta).
- **F4 — «Plan de mi día» con IA:** lee el top ya ordenado y lo explica en texto.

## Estado

- [x] F1 (2026-10-21) — migración `20261025120000_add_estimated_minutes_to_case_tasks`;
  `Cases::TaskPriorityScore`; `mode=my_day` en `Cases::TasksInboxQuery` (+ `meta.agenda`,
  `meta.load`); `views/gestorTickets/tasks/MyDay.vue`; `helper/caseTaskPriority.js`;
  duración estimada en los dos formularios de tarea; pestañas Mías · No asignadas · Todas ·
  Mi día. Specs: `task_priority_score_spec`, `case_tasks_my_day_spec`, `caseTaskPriority.spec`.
- [x] F2 (2026-10-21) — migración `20261025130000_add_my_day_plan_to_case_tasks`
  (`planned_on` — nació como `focus_on` y se renombró antes del commit —, `focus_position`, `focused_at`); `Cases::MyDayPlan` (guarda por reemplazo, solo
  pendientes propias); `PUT /case_tasks/my_day_plan`; en `my_day` el plan va primero y
  `meta.new_urgent` = urgentes (puntaje ≥ `URGENT_SCORE` 70) creadas después de armar el plan;
  `tasks/MyDayTaskRow.vue`; «Posponer a mañana» (mueve `planned_on`, no el vencimiento). Columna «Programada» en la
  bandeja (ámbar si queda después del vencimiento) y campo en los dos formularios de tarea.
  **El día del plan lo manda el navegador** (fecha local): el servidor corre en UTC y en México
  el día cambiaría a las 18:00. Se acepta hoy ±1 día del servidor.
- [x] F3 (2026-10-21) — migración `20261025140000_add_task_priority_weights_to_case_settings`
  (`case_settings.task_priority_weights` jsonb: **solo lo que la cuenta cambió**; lo igual al de
  fábrica no se guarda). `CaseSetting#task_priority_weights_effective`; validación −100…200 (el
  umbral `urgent_score` 1…500, también configurable). `GET/PATCH /case_setting` trae vigentes y
  de fábrica. Página **Configuración → Tareas** (`TaskPriorityConfig.vue`, solo admin): pesos
  por grupo, dos ejemplos que se recalculan en vivo y «Restaurar de fábrica».
  Spec: `case_task_priority_weights_spec`.
- [x] F4 (2026-10-21) — acción de IA `day_plan` en `CaseAiConfig::ACTIONS` (se apaga/enciende en
  Configuración → IA). `Cases::Ai::DayPlanner` (manda «Mi día» ya ordenado — máx. 15 —, la agenda
  y las duraciones; pide JSON `intro/steps/later/warning`; filtra ids que no sean del agente).
  `POST /case_tasks/my_day_ai` (`day`, `tz` del navegador: las horas van en la zona del agente).
  `tasks/MyDayAiPlan.vue`: botón «Plan de mi día (IA)»; los «Puede esperar a mañana» se aplican
  solo con «Pasar a mañana». **No reordena.** Spec: `case_tasks_my_day_ai_spec` (IA simulada).
