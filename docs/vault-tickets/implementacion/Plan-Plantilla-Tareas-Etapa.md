# Plan — Plantilla de tareas por etapa

> **Estado: ✅ HECHO** — T1–T4 (2026-10-22). La T5 sigue en [[Plan-Delegar-Agente-Caso]] como D8.
> Relacionado: [[Plan-Delegar-Agente-Caso]] (la T5 pasó allá como D8) · [[Plan-Bandeja-Prioridad]]
> («Mi día» ordena estas tareas) · [[Plan-Columnas-Por-Tipo]] (las etapas del tipo)

## La idea en una frase

Cada tipo de caso tiene, en cada etapa, su **plantilla de tareas**. Al entrar a la etapa se
crean solas, el usuario sabe qué le toca hacer y, al terminar las obligatorias, el caso
**sugiere** pasar a la siguiente etapa. Nunca avanza si falta documentar algo.

## Decisiones (2026-10-22)

1. **Las tareas se crean al entrar a cada etapa**, no todas al crear el caso. Las de las
   siguientes etapas se ven en gris como **«Próximas»**, para que el usuario conozca todo el camino.
2. **El avance arranca en «Sugerir»:** al terminar las obligatorias, aviso al responsable
   «Listo para pasar a X [Pasar]». Cada etapa puede cambiarse a «Automático» o «Manual».
3. **Las tareas de la plantilla son del responsable del caso** por defecto; opción de una
   persona fija o un equipo.
4. **Nunca se avanza sin documentar.** Si la siguiente etapa pide datos de una persona (cierre en
   Resuelto/Cerrado, resultado en Ganada/Perdida, fecha en Pospuesta), no se mueve: se crea una
   **tarea obligatoria** «Documenta el cierre…». Esa tarea **no se puede palomear a mano**: se
   completa sola cuando se documenta (al llenar el cierre, el resultado o la fecha), y con eso el
   caso pasa a la etapa.
5. **La T5** (evento «Etapa completada» y acciones de etapa en la Automatización) se guarda en
   [[Plan-Delegar-Agente-Caso]] como **D8**.

## Lo que hay hoy (revisado)

- Etapas = `case_type_columns` del tipo (label, color, position, statuses, outcome, probability);
  nacen de `CaseTypeColumn::*_TEMPLATE` según la clase. El caso recuerda la suya en
  `case_tickets.case_type_column_id`.
- Tareas = `case_tasks` (título, estado pending/done, vence, prioridad, responsable, hito,
  minutos estimados, planeada para…). Se crean a mano; no saben de etapas.
- Nada cambia de etapa solo: se mueve en el Tablero (`move`, que pide cierre/resultado/fecha con
  `requires_closure` / `requires_postpone`) o con «Cambiar estado». Las Reglas de casos cambian el
  estado, no la etapa.

## Diseño

### 1. Configuración (Tipos de caso → tipo → Columnas)

Cada etapa se despliega con su lista de tareas y su forma de salida.

| Campo de la tarea plantilla | Ejemplo |
|---|---|
| Título y descripción | «Armar cotización» |
| Obligatoria para avanzar | ✔ |
| Vence | N días u horas **después de entrar a la etapa** |
| Prioridad | Alta |
| Minutos estimados | 30 (para «Mi día») |
| Responsable | Responsable del caso (defecto) · persona fija · equipo |
| Orden | 1, 2, 3… |

Por etapa: **«Al terminar las obligatorias»** → Sugerir (defecto) · Automático · Manual.

### 2. Al entrar a una etapa

- Se crean las tareas de su plantilla, ligadas a la etapa y a la tarea plantilla de origen.
- Si el caso **regresa** a una etapa donde ya estuvo, no se duplican (se reabren las pendientes).
- En la pestaña Tareas: las de la etapa actual arriba; las de las siguientes etapas en gris como
  «Próximas» (vista, no tareas reales).
- Cambiar la plantilla **no toca casos existentes**: aplica a las siguientes entradas.
- Las tareas creadas a mano **no cuentan para avanzar**, salvo que se marquen obligatorias.

### 3. Avance al terminar las obligatorias

- **Sugerir:** aviso en el caso y tarea/aviso en «Mi día»: «Listo para pasar a Negociación [Pasar]».
- **Automático:** pasa solo, con el mismo servicio que el Tablero (respeta transiciones válidas).
- **Manual:** nada.
- **Tope:** si la siguiente etapa pide datos (decisión 4) → tarea obligatoria «Documenta…», que se
  completa sola al documentar y entonces mueve el caso.

### 4. Resaltar qué mueve cada etapa

- **Configuración:** cada etapa muestra cómo se sale: ⚙ Automático / 💡 Sugerir al terminar N
  obligatorias · 🤖 Automatización «X» (cuando exista D8) · ✋ Manual. Aviso si dos cosas mueven
  la misma etapa.
- **Caso:** junto a la etapa actual, «Pasa a Negociación al terminar las tareas · 1 de 2 hechas».
- **Línea de tiempo:** quién lo movió: «se terminaron las tareas de Propuesta», «la
  automatización X» o «Ana».

## Fases

| Fase | Qué | Estado |
|---|---|---|
| T1 | Plantilla de tareas por etapa: tabla nueva `case_type_column_tasks` (migración), modelo, API y edición en Tipos de caso → Columnas; opción de salida por etapa | ✅ |
| T2 | Crear las tareas al entrar a la etapa (alta del caso, Tablero, cambio de estado), sin duplicar al regresar; «Próximas» en gris | ✅ |
| T3 | Avance al terminar las obligatorias (sugerir / automático / manual) + tarea «Documenta…» que se completa sola + línea de tiempo | ✅ |
| T4 | Resaltar qué mueve cada etapa (configuración, caso, aviso de conflicto) | ✅ |
| ~~T5~~ | Pasó a [[Plan-Delegar-Agente-Caso]] como D8 | → |

## Bitácora

- 2026-10-22 — Diseño y decisiones del usuario (1 al entrar a cada etapa, 2 sugerir, 3
  responsable del caso, 4 nunca avanza sin documentar: tarea obligatoria que se completa sola).
- 2026-10-22 — **T1 hecha.** Migraciones `20261027120000_create_case_type_column_tasks` y
  `20261027120100_add_advance_mode_to_case_type_columns`; modelo `CaseTypeColumnTask`
  (prioridad como CaseTask, responsable case_assignee/user/team); `CaseTypeColumn#task_templates`
  y `advance_mode` (suggest/automatic/manual); API anidada
  `case_types/:id/columns/:column_id/tasks` (+ `reorder`), solo admin escribe; la columna expone
  `advance_mode` y `tasks_count`. Front: columna «Tareas (N)» en Tipos de caso → Columnas y
  `typeDetail/StageTasksModal.vue` (guarda al momento; solo etapas ya guardadas). Pruebas:
  `spec/requests/api/v1/accounts/case_type_column_tasks_spec.rb` (9). Al reemplazar columnas
  las tareas se conservan (upsert por id). Todavía no crea tareas en los casos (T2).
- 2026-10-22 — **T2 hecha.** Migración `20261027130000_add_stage_template_to_case_tasks`
  (`case_tasks`: `case_type_column_task_id`, `case_type_column_id`, `required`, `team_id`).
  `CaseTicket#current_stage_column` (su columna o la primera del tipo que cubre su estado, como el
  tablero) y `after_commit :create_stage_tasks` (alta, columna, estado o tipo) →
  `Cases::StageTasksService` (idempotente por tarea plantilla; no en casos cerrados; equipo =
  sin persona con el equipo anotado, salvo que el responsable sea del equipo; evento
  `stage_tasks_added`). `Cases::StagePlan` → `stage_plan` en `GET …/tasks` (etapas siguientes con
  plantilla, sin las de caso cerrado). Front: etiqueta «Obligatoria» y «Equipo: X» en la tabla de
  Tareas, bloque «Próximas» en gris, evento en el Historial; en Tipos de caso las etapas de caso
  cerrado no ofrecen tareas («—»). Pruebas: `spec/services/cases/stage_tasks_service_spec.rb` (6);
  183 pruebas de casos pasan. No avisa al responsable de las tareas nuevas (sin notificación).
- 2026-10-22 — **T3 hecha.** Migración `20261027140000_add_documentation_for_column_to_case_tasks`.
  `Cases::StageAdvance`: `summary` (en `GET case_tickets/:id` como `stage_advance`) y `call`
  (desde `CaseTask after_commit` al terminar/quitar una obligatoria). Siguiente etapa = la primera
  después de la actual que no sea solo de espera (salta Pospuesta / En espera / Pausada). Pide
  documentar si la siguiente tiene resultado, su estado cierra (resolved/validating/closed/
  cancelled) o, en Comercial, pospone → crea una sola tarea obligatoria «Documenta para pasar a
  «X»» (`documentation_for_column_id`), que la API no deja completar a mano y que
  `StageTasksService` cierra sola cuando el caso sale de la etapa. Automático = mismo criterio de
  estado que el tablero + evento `stage_advanced`. Front: `stage/StageAdvanceBanner.vue` en el
  detalle («Pasar a X» / «Documentar y pasar a X», usa `moveToColumn`, así abre el modal de
  cierre/resultado/fecha); en Tareas, «Se completa al documentar» en lugar de «Completar»; la
  pestaña recarga al cambiar de etapa. Pruebas: `stage_advance_spec.rb` (6) +
  `case_tasks_documentation_spec.rb` (1); 263 pruebas de casos pasan (se corrigió
  `pipeline_builder_spec` M1, que dependía de la fecha de hoy).
- 2026-10-22 — **T4 hecha.** `Cases::StageMovers` (por etapa: `required_count`, `rules_in` =
  reglas de casos activas que aplican al tipo y cuyo `change_status`/`escalate`/`close_ticket`
  cae en esa etapa, y `warnings` = etapa en automático + regla que le cambia el estado a otro),
  expuesto en `column_json`. Front: en Columnas, bajo «Tareas (N)», cómo sale (pasa sola / sugiere
  al terminar N obligatorias / a mano), «Regla «X» trae casos aquí» y el aviso de choque; en el
  detalle, `StageAdvanceBanner` muestra el avance («1 de 2 obligatorias hechas. Al terminar…»)
  y el aviso verde cuando está listo. Quién movió el caso ya lo dice el Historial (persona,
  regla o «al terminar las tareas obligatorias»). Pruebas: `stage_movers_spec.rb` (4); 267 de
  casos pasan. Pendientes fuera del plan: notificar al responsable (tareas nuevas / etapa lista)
  y marcar como obligatoria una tarea creada a mano.
- 2026-10-22 — **Extras.** (1) Avisos en la campanita: tipos `case_stage_tasks` (14) y
  `case_stage_ready` (15) en `Notification` (el 13 es `missed_call`, de llamadas, en develop); `Cases::StageNotifier` manda UN aviso por persona al
  nacer sus tareas de la etapa (tarea de equipo sin persona → a todo el equipo) y avisa al
  responsable cuando la etapa queda lista (o hay que documentar); nunca a quien hizo el
  movimiento; texto en el idioma de la cuenta; toast en `actionCable.js`. (2) Casilla
  «Obligatoria para avanzar» en «Nueva tarea» (solo si el caso tiene etapa): la tarea manual queda
  en la etapa actual y cuenta para el avance. Pruebas: `stage_notifier_spec.rb` (5) + 1 en
  `case_tasks_documentation_spec.rb`. Ojo (ajeno): la página Notificaciones se queda en
  «Cargando» por un aviso de recordatorio de calendario sin `meta.assignee` (NotificationTable).
- 2026-10-22 — **«Tienes N avisos importantes» en Mi día.** `Cases::MyDayNotices` + `GET
  case_notices`: avisos SIN LEER de la campanita (todos: casos y conversaciones) con peso — alto
  (rojo): etapa lista que pide documentar, tareas nuevas urgentes/que vencen hoy, caso asignado con
  SLA en riesgo/vencido, SLA de conversación, mención; medio (ámbar): etapa lista, tareas nuevas,
  caso/tarea asignada, conversación asignada, mensaje nuevo en asignada, recordatorio de
  calendario; bajo (solo campanita): tarea completada, participando, conversación nueva.
  Front: `tasks/MyDayNotices.vue` arriba de Mi día (globo rojo/ámbar, lista por peso, clic abre
  el caso o la conversación, «Enterado» = PATCH /notifications/:id y baja el contador; se
  refresca al cambiar el contador de la campanita). Pruebas: `my_day_notices_spec.rb` (3).
  Ojo (Chatwoot): `RemoveDuplicateNotificationJob` deja solo el último aviso por persona y
  `primary_actor_id` SIN mirar el tipo → un aviso de la conversación N borra el del caso N.
