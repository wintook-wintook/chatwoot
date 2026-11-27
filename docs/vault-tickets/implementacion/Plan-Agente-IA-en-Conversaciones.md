---
tags: [plan, conversaciones, agentes-ia, campañas]
fecha: 2026-11-26
estado: fase 1 hecha (2026-11-26, rama 26nov, sin commit); falta fase 2
---

# Plan — «Agente IA» en las conversaciones (y campañas que no saturan el chat)

## El problema
1. **Las campañas saturan el chat.** Al salir el primer mensaje, `TrackingCampaigns::TrackingBuilder#open_conversation`
   abre una conversación por contacto **abierta y asignada al dueño de la campaña** (y `ContactTrackingJob` reabre la
   que estaba resuelta). Una campaña de 500 → 500 conversaciones en «Mías» del dueño y en «Todas», aunque nadie haya
   contestado. Solo los de lista fría en cuarentena nacen pospuestos y sin asignar (`quiet`).
2. **No se sabe qué conversación tiene un agente de IA.** El responsable (`conversations.assignee_id`) solo puede ser una
   persona. Que la atiende la IA solo se ve dentro de la conversación: el robot en cada mensaje que escribió la IA
   (`content_attributes.ai_agent`, «Enviado por …» al pasar el mouse) y «Atendida por …» en el panel del contacto
   (`ReadyAgentStatus`). En la lista y en los filtros no aparece.

## Lo acordado (2026-11-26)
- **«Responsable» no se toca:** sigue siendo solo personas y la IA nunca lo mueve.
- **Campo nuevo «Agente IA»** en la conversación, al lado del responsable: el agente que la está atendiendo
  (Atención a clientes, Atención a prospectos, Vendedor de campaña, Seguimiento IA, Cobranza…) o **«Sin agente»**.
  Pueden estar los dos (persona + IA), uno o ninguno.
- **No se dan de alta los agentes de IA como usuarios** (ocuparían licencias y se colarían en usuarios, permisos,
  asignación automática, informes «por usuario», Despacho y notificaciones).
- **Filtro con combo** (no check), junto al de estado arriba de la lista:
  ```
  [ Abiertas ▾ ]  [ 🤖 Agente IA: Todos ▾ ]
     ✓ Todos
       Sin agente IA        ← lo que atienden solo personas
       Con agente IA        ← cualquiera con IA trabajando
       ───────────
       Atención a clientes (12)
       Atención a prospectos (8)
       Vendedor de campaña (15)
       Seguimiento IA (3)
       Cobranza (2)
  ```
  De fábrica «Todos» (no se esconde nada); se recuerda por usuario; si no está en «Todos», el botón se marca de color.
  Se combina con Mías / Sin asignar / Todas: «Sin asignar + Con agente IA» = lo que tiene solo la IA; «Mías + Sin
  agente IA» = lo que me toca solo a mí; «Mías + Seguimiento IA» = mis clientes con seguimiento de la IA.
- **Campañas:** en las conversaciones **nuevas** de campaña el responsable queda **vacío** (no se le pone el dueño) y el
  «Agente IA» es el Vendedor de campaña. Cuando la IA la entrega (le interesa → vendedor, pide una persona, cita, pago
  por verificar), se asigna el responsable como hoy y se avisa. Una conversación que ya tenía responsable se respeta.

## Qué se ve
- **En la conversación:** `Responsable: Juan Pérez` · `Agente IA: 🤖 Seguimiento IA` (o `Sin agente`).
- **En la tarjeta de la lista:** el avatar del responsable como hoy y, junto, la etiqueta «🤖 Atención a clientes» si hay
  agente IA. En las resueltas, en gris y en pasado («Atendió: 🤖 …»).
- **En el menú de Conversaciones:** sección «🤖 Agentes de IA (N)» con cada agente y cuántas tiene en curso; un clic
  abre la lista ya filtrada.
- El robot de cada mensaje se queda como está (quién escribió ese mensaje).

## Cómo (técnico)
### El dato «Agente IA» de la conversación
- **Guardarlo en la conversación** (no calcularlo en cada consulta): columnas en `conversations`
  `ai_agent_kind` (motor2 | follow_up | collections | v1), `ai_agent_ref_id` (id del seguimiento o del agente),
  `ai_agent_name` (lo que se ve) y `ai_agent_function` (prospects, customers, campaign_seller, follow_up, collections…
  para el combo). Índice por `(account_id, ai_agent_function)`.
- **Quién lo prende y lo apaga** (un solo servicio, p. ej. `Conversations::AiAttendant.sync(conversation)`):
  - Motor 2.0: al crear o cerrar el `ContactTracking` vivo de la conversación (`Motor2::LIVE`), al entregarlo
    (Relay / outcomes «relayed», «handed_off»), al pausarlo («Pausar agente») y al terminar.
  - Seguimiento IA: `AiFollowUp.live_for?(conversation_id)` — al crear, pausar o terminar el seguimiento.
  - Cobranza: el agente de la cartera en esa conversación.
  - Agentes 1.0 (a medida): su `ContactTracking` vivo (solo nombre; sin tocar ese motor: ver memoria «No tocar Agentes a medida»).
  - Prioridad si hay más de uno vivo: el más específico (campaña > seguimiento > agente de la bandeja), igual que §11.9.
- Migración que llene el dato de las conversaciones que hoy tienen agente vivo.

### Filtro y menú
- `Conversations::FilterService` / `ConversationFinder`: parámetro `ai_agent` = `with` | `without` | función.
- Contadores por agente para el menú (un `group by ai_agent_function` de las abiertas y pendientes).
- Front: combo en el encabezado de la lista (`ChatList`), etiqueta en `ConversationCard`, campo en el panel de la
  conversación junto a «Responsable» (solo lectura en la fase 1), sección en el menú v2 de Conversaciones.

### Campañas sin saturar
- `TrackingCampaigns::TrackingBuilder#open_conversation`: en campañas 2.0, sin `assignee_id` (como hoy el caso `quiet`).
- `ContactTrackingJob#find_or_create_conversation`: no reabrir como «abierta» una conversación resuelta solo por salir
  un toque de campaña; si hace falta, que quede pendiente (sin persona) hasta que conteste o se entregue.
- Al entregar (`Motor2::Relay`, `CampaignSellerOutcomes`): asignar el responsable y avisar (hoy ya avisa).
- Avisos: no mandar «nueva conversación asignada» por cada contacto de la campaña (ya no habrá asignación de entrada).
- Revisar con la asignación automática de la bandeja: que no tome las conversaciones de campaña sin persona mientras
  las atiende la IA.

## Fases
| Fase | Qué |
|---|---|
| **1** | El dato «Agente IA» (columnas + `AiAttendant.sync` + migración que llena), campo en la conversación junto a «Responsable», etiqueta en la tarjeta, combo «Agente IA» con «Sin agente IA» / «Con agente IA» / por agente, sección «🤖 Agentes de IA» en el menú. Campañas: responsable vacío en conversaciones nuevas y sin reabrir por un toque; se asigna al entregar. |
| **2** | Elegir un agente de IA desde el campo «Agente IA» de la conversación (pasársela a Seguimiento IA, Cobranza…; hoy es «Delegar a agente»), y «Sin agente» para pararlo desde ahí. |

## Decidido al empezar (2026-11-26)
- Lo que atiende solo la IA se queda en «Abiertas» **sin responsable** (no se mueve a «Pendientes»); se separa con el combo.
- **Sí** se resuelve sola cuando la IA (Motor 2.0) termina sin entregarla y nadie la tiene (`ContactTracking` after_update_commit →
  `Conversations::AiAttendant.finished!`); con responsable o entregada, no.
- El dato «Agente IA» **se calcula al consultar** (no se guarda en `conversations`): nunca queda desfasado.
- El menú lleva **una** entrada «Agentes de IA» (`?ai_agent=with`); los conteos por agente van en el combo (el menú es fijo).

## Lo hecho en la fase 1
- `Conversations::AiAttendant` (for / filter / counts / finished!), `ConversationFinder` (`ai_agent` + `ai_agents` en meta),
  `ai_agent` en el JSON de la conversación y en el evento en vivo, guarda en `AutoAssignmentHandler`.
- Campañas: `TrackingBuilder` sin responsable y con `additional_attributes.ai_campaign`; `Motor2::HandoffAssign` al entregar
  (destino o dueño de la campaña) y quita la marca.
- Pantalla: `AiAgentFilter.vue` (combo, se recuerda), etiqueta en `ConversationCard`, campo en `ConversationAction`, menú.

## 🔗 Relacionado
- [[Plan-Motor-Agentes]] (§11.9 un motor, varios agentes) · [[Plan-Delegar-Agente-Caso]]
- Memorias: «Campañas Motor 2.0», «Seguimiento IA», «Agentes listos», «No tocar Agentes a medida».
