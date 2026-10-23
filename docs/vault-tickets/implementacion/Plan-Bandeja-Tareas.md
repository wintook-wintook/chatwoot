---
titulo: Plan — Bandeja de tareas (ver mis tareas sin entrar ticket por ticket)
tipo: plan
tags: [tickets, case_tasks, agentes, bandeja]
---

# Plan — Bandeja de tareas

> Estado: ✅ **implementado F1–F4** (2026-07-29). Verificado en navegador (cuenta 2).
> Ajustes de producto sobre el plan original (2026-07-29): (1) el **toast también
> salta al ASIGNAR** una tarea, no solo al completar (§5.4); (2) **sí se notifican
> las auto-asignaciones** — asignarte una tarea a ti mismo da campanita + toast
> (contradice el §3.2, que copiaba el criterio de tickets).
> Único pendiente menor: badge de vencidas en el item de sidebar (§4.2) — diferido
> para no tocar el layout compartido; el conteo ya se ve en la pestaña "Vencidas (n)".
> Relacionado: [[Conciliacion-osTicket-MGCI]] (§4.4 Tareas/subtareas) ·
> [[Comparativa-Agent-Panel-osTicket]] · [[Pendiente]]

---

## 1. El problema

Las tareas de un ticket **ya se pueden asignar a un agente** — el modelo tiene
`assignee_id` y hasta lo tiene indexado:

```
 case_tasks
   id, account_id, case_ticket_id, title, description
   assignee_id      ──▶ users     ✅ existe
   status           pending | done
   due_at           ✅ existe
   completed_at / completed_by_id  ✅ auditado
   position
   index_case_tasks_on_assignee_id  ✅ existe
```

Pero **no hay forma de preguntar "¿qué tareas tengo asignadas?"**. La única
superficie es `TicketTasks.vue`, dentro de la ficha de un ticket, y el único
endpoint está anidado bajo un ticket concreto:

```
 GET /api/v1/accounts/:id/case_tickets/:case_ticket_id/tasks
                                        ▲
                                        └── obligatorio: hay que saber el ticket de antemano
```

`case_tasks_controller.rb` arranca con `before_action :set_ticket` y su `index`
es `@ticket.case_tasks.ordered`. No existe consulta por agente.

Resultado operativo:

```
  Agente:  "¿qué tengo pendiente?"
     │
     ├─ abrir ticket #1  → mirar pestaña Tareas  → ¿algo mío?
     ├─ abrir ticket #2  → mirar pestaña Tareas  → ¿algo mío?
     ├─ abrir ticket #3  → ...
     └─ (y los tickets que no son suyos, ni se le ocurre abrirlos)
```

El último renglón es el caso grave: si le asignan una tarea en un ticket de otro
agente, **no se entera nunca**. No hay notificación de asignación de tarea
(sí la hay de asignación de *ticket*: `case_ticket_assignment` en
`app/models/notification.rb:49`, disparada desde `case_tickets_controller.rb:835`).

---

## 2. Alcance

**Dentro:**
1. Endpoint de tareas **a nivel cuenta**, filtrable por agente / estado / vencimiento.
2. Vista "Tareas" en el módulo de tickets, con "Mis tareas" por defecto.
3. Contador de pendientes visible sin entrar a la vista.
4. Notificación al agente cuando le asignan una tarea.
5. **Aviso en tiempo real al completar una tarea**, al asignado del ticket y al
   asignado de la tarea (§5).

**Fuera (otro plan):**
- Tareas independientes del ticket (osTicket permite *standalone tasks*; aquí
  `case_ticket_id` es `null: false`).
- Hilo/comentarios propios de la tarea.
- Colaboradores externos en tareas — descartado, ver [[Pendiente]].

---

## 3. Backend

### 3.1 Endpoint nuevo, a nivel cuenta

```
 GET /api/v1/accounts/:account_id/case_tasks
```

Controlador nuevo `Api::V1::Accounts::CaseTasksIndexController` — o, más simple,
una acción extra en el controlador actual desanidada en rutas. **Recomiendo
controlador aparte**: el actual tiene `before_action :set_ticket` en todas las
acciones y meterle una excepción es exactamente la trampa documentada en
[[Plan-Notas-Internas]] (`@ticket` nil disfrazado de 422).

```ruby
# config/routes.rb — al mismo nivel que `resources :case_types`
resources :case_tasks, only: [:index]
```

**Filtros:**

| Param | Default | Nota |
|---|---|---|
| `assignee_id` | `current_user.id` | cualquier agente, sin guard de rol · `unassigned` para las huérfanas |
| `status` | `pending` | `pending` \| `done` \| vacío = todas |
| `due` | — | `overdue` \| `today` \| `week` |
| `case_type_id` | — | reusa el tipo del ticket padre |
| `q` | — | título/descripción de la tarea |

**Respuesta:** la tarea **más el contexto de su ticket**, que es lo que hoy
obliga a entrar. Sin esto la bandeja no sirve de nada:

```
 {
   id, title, description, status, due_at, position,
   assignee: { id, name, avatar },
   case_ticket: {
     id, folio, title, status, priority, sla_status,
     case_type: { id, name, color }
   }
 }
```

**Coste de la consulta:** `index_case_tasks_on_assignee_id` ya existe, así que el
filtro principal va por índice. El join al ticket pide `includes(case_ticket: :case_type)`
para no caer en N+1 al serializar.

**Alcance de visibilidad — DECIDIDO (2026-07-28):** por cuenta, sin restricción por
rol. **Cualquier agente puede filtrar por cualquier otro agente**, no solo los
administradores. El default del filtro es "mis tareas" (comodidad), pero el
selector de agente está abierto para todos.

Coherente con el resto del módulo: el listado de tickets tampoco restringe por
agente. Implicación para el código: el `index` **no** lleva guard de rol sobre
`assignee_id`; basta el scope de cuenta (`Current.account`).

### 3.2 Notificación al asignar

Copiar el patrón que ya existe para tickets:

```
 notification.rb:49   NOTIFICATION_TYPES  case_ticket_assignment: 10
                                          case_task_assignment:   11   ◀── NUEVO

 case_tasks_controller.rb  create/update → si assignee_id cambió y no soy yo
                                          → NotificationBuilder.new(...)
```

Hay que añadir también la clave de título
(`notifications.notification_title.case_task_assignment`) y el `when` del
`push_event_data`, siguiendo los tres puntos que ya toca
`case_ticket_assignment` en `notification.rb:108`, `:118` y `:141`.

Ojo con el `frozen_for_edit?`: el controlador actual bloquea todo cambio si el
ticket está cerrado. La notificación va después de ese guard, no antes.

---

## 4. Frontend

### 4.1 Vista nueva

```
 routes.js →  path:  accounts/:accountId/tickets/tasks
              name:  gestorTickets_tasks
              vista: views/gestorTickets/Tasks.vue          ◀── NUEVO
              sidebar: "Tareas" (junto a Tickets / Kanban)
```

```
 ┌─ Tareas ─────────────────────────────────────────────────────────────┐
 │  [ Mis tareas ] Sin asignar │ Todas │ Vencidas (3)                    │
 │  Agente [ ▾ ]  Estado [Pendiente ▾]  Vence [ ▾ ]   🔍 ______________  │
 ├──────────────────────────────────────────────────────────────────────┤
 │ ☐  Pedir refacción al proveedor                                      │
 │    SOP-000142 · Impresora no imprime      🔴 Alta   vence: hoy       │
 │ ☐  Confirmar dirección de entrega                                    │
 │    REP-000088 · Cambio de disco           🟠 Media  vence: 30 jul    │
 │ ☑  Cotizar con Daiko                                    completada   │
 │    REP-000088 · Cambio de disco                    por María, 27 jul │
 └──────────────────────────────────────────────────────────────────────┘
```

Cada renglón lleva el **folio + título del ticket** como liga a la ficha: la
bandeja resuelve el "qué tengo", y un clic lleva al contexto completo.

Marcar ☐/☑ desde la bandeja reusa el `PATCH` anidado que ya existe
(`caseTasks.js` → `updateTask(ticketId, id, data)`), no hace falta endpoint nuevo
de escritura: la respuesta del index ya trae `case_ticket.id`.

### 4.2 Contador

El valor real está en no tener que abrir la vista. Un badge de pendientes
vencidas junto al item de sidebar, alimentado por el mismo endpoint con
`status=pending&due=overdue&per_page=1` leyendo el total.

### 4.3 Archivos

| Archivo | Acción |
|---|---|
| `api/caseTasks.js` | añadir `getMine(filters)` contra la ruta no anidada |
| `store/modules/caseTickets.js` | estado `myTasks` + getters + action `fetchMyTasks` |
| `views/gestorTickets/Tasks.vue` | **nueva** |
| `routes/dashboard/gestorTickets/routes.js` | ruta nueva |
| sidebar del módulo | item "Tareas" + badge |
| `i18n/.../gestorTickets.json` | claves de la vista |

---

## 5. Aviso en tiempo real al completar una tarea

### 5.1 Por qué no basta con un toast

El toast de hoy (`$emitter.emit('newToastMessage', ...)`, 17 vistas lo usan) es
**puramente local**: `SnackbarContainer.vue` escucha el emitter del *propio*
navegador. No sale de la pestaña de quien hizo clic. Para que lo vea otro agente
hace falta empujar el evento por WebSocket.

Detalle menor de UX: el contenedor está en **arriba al centro**
(`left-0 right-0 mx-auto ... top-4`), no en una esquina, y dura **2500 ms**
(`duration` por defecto). Si se quiere esquina, es un cambio de clases en ese
componente — aplicaría a todos los toasts del producto, no solo a estos.

### 5.2 Lo que ya está montado (y es casi todo)

El módulo de tickets **no tiene tiempo real todavía** — de ahí que el lock solo
se entere "al abrir/refrescar". Pero la vía por usuario ya existe y funciona,
por el carril de notificaciones:

```
  NotificationBuilder.new(...).perform          app/builders/notification_builder.rb
        │  crea Notification
        ▼
  dispatch 'notification.created'
        │
        ▼
  ActionCableListener#notification_created      action_cable_listener.rb:4
        │  tokens = [notification.user.pubsub_token]   ◀── UN usuario concreto
        ▼
  WebSocket ─────▶ actionCable.js:180  onNotificationCreated
                        │
                        └─▶ store 'notifications/addNotification'   → campanita 🔔
                            (hoy NO dispara toast)
```

O sea: **entrega dirigida a un usuario específico, ya resuelta y en producción**
(la usa `case_ticket_assignment`, `case_tickets_controller.rb:835`). Lo único que
falta es (a) crear la notificación al completar, y (b) que el front, además de
meterla en la campanita, saque el toast.

### 5.3 A quién le llega

```
  Tarea "Pedir refacción" del ticket SOP-000142  →  marcada ☑ por Pedro

     destinatarios = { ticket.assignee , task.assignee } − { quien marcó }

     ┌──────────────────────┬──────────────┬──────────────────────────────┐
     │ ticket.assignee      │ task.assignee│ resultado                    │
     ├──────────────────────┼──────────────┼──────────────────────────────┤
     │ María                │ Juan         │ avisa a María y a Juan  (2)  │
     │ María                │ María        │ avisa a María           (1)  │
     │ María                │ Pedro ◀marca │ avisa solo a María      (1)  │
     │ Pedro ◀marca         │ Juan         │ avisa solo a Juan       (1)  │
     │ Pedro ◀marca         │ Pedro        │ no avisa a nadie        (0)  │
     │ (sin asignar)        │ Juan         │ avisa solo a Juan       (1)  │
     └──────────────────────┴──────────────┴──────────────────────────────┘
```

Reglas: deduplicar cuando coinciden, excluir siempre al que ejecutó la acción
(él ya ve el cambio en pantalla), y saltar los `nil`. Mismo criterio que ya aplica
`notify_assignee` al no notificar auto-asignaciones.

### 5.4 Dos caminos

| | **(a) Reusar notificaciones** | **(b) Evento efímero propio** |
|---|---|---|
| Backend | `NotificationBuilder` × destinatarios | evento nuevo + método en `ActionCableListener` |
| Frontend | toast desde `onNotificationCreated` filtrando por tipo | handler nuevo en el mapa de `actionCable.js:12` |
| Persiste en campanita | sí | no |
| Si el agente está desconectado | lo ve al volver | **se pierde** |
| Esfuerzo | bajo | medio |

**Recomiendo (a).** El argumento de peso no es el esfuerzo sino la degradación:
un toast puro se evapora si el agente no tenía la pestaña abierta, y "me avisaron
cuando no estaba" es exactamente el agujero que este plan quiere tapar. Con (a),
el toast es la capa bonita y la campanita es la red de seguridad.

Contra de (a): ensucia la campanita con eventos de bajo valor. Si molesta, la
salida es marcar el tipo como auto-leído en lugar de irse a (b).

### 5.5 Qué tocar

**Backend:**
- `notification.rb:49` → `case_task_completed: 12` en `NOTIFICATION_TYPES`, más los
  tres puntos que ya toca `case_ticket_assignment` (`:108` título, `:118` y `:141`
  en `push_event_data`).
- `case_tasks_controller.rb#update` → tras el `save`, si `status` pasó a `done`,
  construir la notificación para los destinatarios de §5.3. Igual que
  `notify_assignee`: en un `rescue StandardError` que loguea y no rompe el flujo.
- ⚠️ Va **después** del guard `frozen_for_edit?`, no antes.
- **`primary_actor` debe ser el TICKET, no la tarea.** Tentador poner la tarea,
  pero eso obligaría a implementar `push_event_data` en `CaseTask` (hoy no lo
  tiene; `CaseTicket` sí, `case_ticket.rb:197`) **y** a enseñarle al front a
  navegar a una tarea. Con el ticket como `primary_actor` se hereda tal cual el
  ruteo que ya funciona para `case_ticket_assignment`, y el nombre de la tarea
  viaja en el título. Un campo menos que construir y un clic que ya sabe a dónde ir.

**Frontend:**
- `actionCable.js:180` `onNotificationCreated` → además del dispatch al store,
  emitir `newToastMessage` cuando el tipo esté en una lista blanca. Conviene que
  sea lista blanca y no "todas": convertir cada notificación en toast cambiaría el
  comportamiento de todo el producto, no solo el de tickets.

### 5.6 Sin correo — DECIDIDO (2026-07-28)

**Solo campanita + toast. Nada de email ni push.** Y la buena noticia: *no hay que
implementar nada para lograrlo*, es el comportamiento por defecto.

El correo no sale de `NotificationBuilder` sino de un callback del modelo:

```
  Notification  after_create_commit :process_notification_delivery   notification.rb:55
        │
        ├─ PushNotificationJob   si user_subscribed_to_notification?('push')    :176
        └─ EmailNotificationJob  si user_subscribed_to_notification?('email')   :181
                                    ▲
                                    └── bit del tipo en notification_settings.email_flags
```

Y al crear un `account_user`, los únicos flags que se encienden son:

```ruby
# app/models/account_user.rb:56-57
setting.selected_email_flags = [:email_conversation_assignment]
setting.selected_push_flags  = [:push_conversation_assignment]
```

Es decir: **cualquier tipo nuevo nace apagado** para email y push. `case_task_completed`
no mandará correo a nadie sin que alguien lo active a mano.

Para que además sea *inactivable*: no agregar la clave del tipo a la pantalla de
preferencias de notificación (las etiquetas viven en `generalSettings.json:87-94`,
donde sí está `case_ticket_assignment`). El bit existe en la máscara pero nadie
puede alcanzarlo desde la UI. Con eso basta — no hace falta tocar
`process_notification_delivery`, que es código core de Chatwoot.

### 5.7 Lista de notificaciones — sale gratis

Sí, se ve también ahí, y sin trabajo extra: la campanita y la página completa
(`accounts/:accountId/notifications`, ruta `notifications_index`) **leen los mismos
registros `Notification`**. No son dos sistemas, es una tabla con dos superficies.

```
                    Notification (registro en BD)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         🔔 campanita    📄 lista de      💬 toast
          (dropdown)     notificaciones    (§5.2, F4)
              │               │               │
              └── ambas ya existen ──┘    lo único
                  y funcionan solas       por construir
```

Esto refuerza la elección del camino (a) en §5.4: una sola inserción produce las
tres superficies. Con el camino (b) —evento efímero propio— habría toast y nada más.

**Requisito para que la fila se vea bien:** hay que dar de alta el tipo en los tres
puntos de `notification.rb` que ya toca `case_ticket_assignment` (`:108` título,
`:118` y `:141` en `push_event_data`). Si se omiten, la notificación se crea pero
la fila sale sin título o revienta el render de la lista.

---

## 6. Fases

```
 F1  Endpoint      GET /case_tasks a nivel cuenta, con filtros y contexto
                   del ticket
                   ───────────────────────────────────────── testeable por curl/consola

 F2  Vista         Tasks.vue + ruta + sidebar; marcar completada inline
                   ───────────────────────────────────────── ✅ resuelve el problema planteado

 F3  Notificación  case_task_assignment + badge de pendientes
                   ───────────────────────────────────────── cierra el caso "no me entero"

 F4  Tiempo real   case_task_completed + toast desde onNotificationCreated
                   ───────────────────────────────────────── §5, avisa a ticket.assignee + task.assignee
```

F1+F2 ya quita el "entrar ticket por ticket". F3 es lo que evita que una tarea
asignada en un ticket ajeno se pierda, que es la mitad menos visible del problema.
F4 depende de F3: comparte el tipo de notificación, el listener y el handler del
front, así que hacerlas juntas sale más barato que separadas.

---

## 7. Pruebas

**Backend:**
- Tarea asignada al agente A → aparece en el index de A por defecto, y **no** en
  el de B por defecto.
- B (agente normal, sin rol admin) filtra por `assignee_id=A` → **sí** ve las
  tareas de A. Si esto devuelve 403, el guard de rol se coló donde no debía.
- `status=pending` por defecto → las `done` no ensucian la bandeja.
- `due=overdue` → solo `due_at < ahora` y `pending`.
- Tarea sin `assignee_id` → sale con `assignee_id=unassigned`, no en "mis tareas".
- Ticket cerrado → sus tareas se listan pero no se pueden marcar (`frozen_for_edit?`).
- Verificar que no hay N+1 al serializar el ticket y su tipo.

**Navegador:**
- Asignar una tarea a otro agente desde la ficha → ese agente la ve en su bandeja
  **sin haber abierto nunca ese ticket** (el caso que motiva el plan).
- Marcar completada desde la bandeja → desaparece del filtro pendiente y la ficha
  del ticket lo refleja.
- Clic en el folio → navega a la ficha correcta.
- Badge de vencidas cuadra con el total del filtro.

**Tiempo real (§5) — con dos navegadores abiertos:**
- María (asignada del ticket) y Juan (asignado de la tarea) con el dashboard
  abierto; Pedro marca la tarea ☑ → el toast aparece en **ambas** pantallas, y en
  la de Pedro no.
- María es a la vez asignada del ticket y de la tarea → **un solo** aviso, no dos.
- Juan marca su propia tarea → solo se entera María.
- Juan con la pestaña cerrada → al volver, lo encuentra en la campanita (esta es
  la prueba que justifica haber elegido el camino (a) sobre el (b)).
- La misma notificación aparece en la campanita **y** en la lista completa
  (`/accounts/:id/notifications`), con título legible y clic que abre el ticket.
- **Ningún correo sale** (revisar la cola / el log de `EmailNotificationJob`), ni
  push. Es lo esperado por defecto según §5.6, pero conviene verlo con los ojos.
- El tipo `case_task_completed` **no aparece** en la pantalla de preferencias de
  notificación del perfil.
