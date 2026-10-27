# Plan — Embudo de contactos

> Estado: ✅ **E1, E2 y E3 hechos** (2026-10-23, rama `feat/nva_oportunidad`).
> El tablero de conversaciones (KANBAN0725) es la antesala del caso comercial: el prospecto
> avanza solo con lo que pasa en su conversación y, cuando hay interés real, nace la oportunidad.

## Decisiones del usuario
- Nombre: **«Embudo de contactos»** (solo cambia el texto; la URL `/kanban` sigue igual).
- **Los tableros que ya existen no cambian**: todo lo nuevo les llega apagado y la empresa lo
  configura si quiere. **Los tableros nuevos nacen con todo configurado** (plantilla).
- Reparto: **los hechos los mueve una regla** (seguros, sin costo), **la intención la mueve la
  IA** (criterio en palabras por columna + nota privada), **la etiqueta es opcional**.
- Candados: solo hacia adelante, **mover a mano siempre gana**, la IA nunca crea la
  oportunidad sola.

## Cómo funciona
| Pieza | Dónde |
|---|---|
| Disparadores por columna («Entra aquí cuando…»): `conversation_created`, `first_reply`, `label_added` (etiquetas), `appointment_scheduled`, `case_created` (clase), `conversation_resolved` | `KanbanProcess#entry_triggers`, `TRIGGER_TYPES`, `triggered_by?` |
| Tipo de columna: `open` / `converted` / `discarded`; tipo de caso a crear al soltar | `stage_kind`, `convert_case_type_id` |
| Embudo: `auto_move`, `ai_move`, `entry_inbox_ids`, `cold_after_days`, `discard_after_days` | `kanban_type_processes` |
| Mueve la tarjeta (entrar, avanzar, regresar al escribir el cliente) | `Kanban::FunnelMover` |
| Escucha la conversación (nueva, primera respuesta, etiqueta, mensaje del cliente, resuelta) | `KanbanFunnelListener` (AsyncDispatcher) |
| Citas y casos (fuera de la conversación) | `after_commit` en `ContactTracking` (appointment_at), `CaseMeeting`, `CaseTicket` (conversation_id) → `Kanban::FunnelTriggerJob` |
| Quién movió y por qué (todas las vías, incluso los endpoints viejos) | concern `KanbanFunnelTrackable` → columnas `kanban_moved_*` + tabla `kanban_moves` |
| Plantilla de tablero nuevo (6 columnas, reglas, criterios IA, etiqueta «interesado») | `Kanban::FunnelTemplate` (en `create`; `blank: true` lo deja vacío) |
| IA: avanza si está segura (≥ 0.75) o solo sugiere (≥ 0.5) con nota privada | `Kanban::FunnelAi` (llave OpenAI de la cuenta), `Kanban::FunnelAiJob` (espera 2 min, solo el último mensaje) |
| Vencimientos: «Frío» (lo calcula el tablero) y descarte automático | `kanban_controller#cold_ids`, `Kanban::FunnelStaleJob` (cron cada hora, min 17) |
| Columna «Convertir»: soltar a mano crea la oportunidad (reusa «Asignar Caso») | `Kanban::FunnelConverter` |
| Métricas: entradas, alcance por columna, conversión, días, descartes, quién movió, aciertos de la IA | `Kanban::FunnelMetrics`, `GET kanban_type_processes/:id/funnel_metrics?days=` |

Front: `components/kanban/funnel/` (`ColumnFunnelFields`, `BoardFunnelFields`,
`FunnelMetricsModal`), conectados en Configuración › Kanban y en el tablero (botón «Métricas»).
La tarjeta muestra el motivo del último movimiento, el chip «→ folio» del caso y «❄ Frío».

## Reglas finas
- Una conversación entra sola **solo si no está ya en un tablero** (una automatización la pudo meter).
- Desde «Convertido» ya no se mueve; desde «Descartado» solo sale si **se crea su caso** o si
  **el cliente vuelve a escribir** (regresa a la columna de entrada).
- «Primera respuesta» = primer mensaje público de una persona, AgentBot o Captain (no campañas
  ni notas privadas).
- Las métricas cuentan desde que existe `kanban_moves` (no hay historia anterior).

## Fases
- **E1** ✅ nombre, disparadores de hechos, interruptor, bitácora, plantilla, specs de compatibilidad.
- **E2** ✅ IA con criterio por columna + nota privada, regreso del cliente, resuelta sin caso,
  vencimientos, columna «Convertir».
- **E3** ✅ métricas del embudo (incluye correcciones de la IA: movida a mano ≤ 72 h después).

## Mejoras (27/10/2026, rama `feat/chat_interno_pulido`)
- **Que no se acumulen:** en Convertido y Descartado el tablero trae solo lo que llegó en los
  últimos N días (selector «Convertidas y descartadas»: 7 / 30 / 90 / Todas; 30 por omisión,
  lo recuerda cada quien en el navegador). Al pie de la columna «+ N más antiguas · ver».
  Servidor: `closed_days` en `filter_by_both_kanban` (fecha = `COALESCE(kanban_moved_at,
  created_at)`) y `meta.older_count`. No borra nada; las métricas cuentan todo.
- **Resolver al descartar:** `kanban_type_processes.resolve_on_stale` (migración 20261030170000).
  Si el vencimiento descarta la tarjeta, la conversación se resuelve con `update_columns`: sin
  mensaje de actividad (→ sin encuesta CSAT), sin CONVERSATION_RESOLVED ni webhooks. La nota
  dice «…se resolvió la conversación sin avisarle». Tableros nuevos en true; existentes en false.
  La casilla sale en Ajustes › Embudos solo si hay «Descartar tras N días».
- **Convertido listo:** la plantilla pone en la columna Convertido el primer tipo comercial
  vigente (`convert_case_type_id`); sin tipos comerciales se queda vacío (convierte solo por regla).

## Specs
`spec/requests/api/v1/accounts/kanban_funnel_compat_spec.rb` (lo de antes sigue igual),
`spec/services/kanban/funnel_mover_spec.rb`, `funnel_e2_spec.rb`, `funnel_metrics_spec.rb`,
`spec/listeners/kanban_funnel_listener_spec.rb`.

## Pendiente / ideas
- Mover el embudo al menú «Ventas › Embudo de contactos» (reacomodo del menú, siguiente tema).
- Acciones del embudo en el catálogo de [[Plan-Delegar-Agente-Caso]] (mover tarjeta desde un agente).
- Ver [[Trampas]] #27 (tablas sin migración) y #28 (orden por defecto de `Message`).
