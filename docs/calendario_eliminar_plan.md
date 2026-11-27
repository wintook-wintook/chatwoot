# Calendario: cancelar tareas agendadas, eliminar eventos y colores de compañeros

> Rama: `fix/calendario_eliminar` (desde `origin/develop` 30ea1138, ya incluye el PR #215) · Plan v1.3 · 26/11/2026 (v1.1: punto 3, colores de compañeros · v1.2: D1–D7 confirmadas, F0 completa · v1.3: colores en ventana con icono ⚙)
> Estado: **D1–D7 confirmadas** (recomendaciones) · **F0–F4 completas** · sigue F5 (pruebas en navegador).

---

## 1. Qué se pide

Hoy, en la pantalla del calendario, al abrir una cita **solo se puede editar o mover**. No hay
cómo quitarla. Se piden dos cosas:

1. **Tarea agendada:** botón **«Cancelar tarea agendada»** en su ventana, con motivo y con aviso
   a los participantes (y al cliente si se quiere), como ya se hace desde el caso.
2. **Evento de Google** (el que se crea como «Evento», sin tarea): botón **«Eliminar evento»**
   con confirmación; se borra en Google y, si tenía invitados, Google les avisa.
3. **Colores de compañeros:** en «Calendarios → Compañeros», poder **personalizar el color de
   fondo y de letra** de cada compañero.

---

## 2. Cómo está hoy

```
  Clic en una cita del calendario
            │
            ▼
  CreateEventModal (modo editar)
  ┌──────────────────────────────────────────────────────────┐
  │  Editar evento                                       ✕   │
  │  …campos…                                                │
  │                                                          │
  │  [Pasar a tarea]                   [Cancelar] [Guardar]  │
  │   (solo tarea agendada)             └ cierra la ventana  │
  └──────────────────────────────────────────────────────────┘
       ✗ no hay cancelar la tarea agendada
       ✗ no hay eliminar el evento
```

Lo que **ya existe** en el servidor y se va a reusar:

```
  Tarea agendada (CaseMeeting)
  ├─ PATCH /agenda_items/:id { status: 'cancelled', reason_id, comment, minutes,
  │                            scope: one|all, notify_client }
  │     → Cases::Cancellation: motivo del catálogo, historial, serie completa,
  │       quita el evento de Google (GoogleMirrorService) y avisa a participantes
  └─ DELETE /agenda_items/:id  → solo errores de captura (quien la creó, primeras 24 h,
                                  o administrador). NO se usa en este plan (ver D1).

  Ventana «Cancelar con motivo»: components/cancel/CancelItemModal.vue
  (la usan Tickets → Tareas, el caso → Tareas agendadas y Tareas)
  · primero ofrece reprogramar · motivo · tiempo dedicado · esta o toda la serie · avisar al cliente

  Evento de Google
  └─ GoogleCalendarService#delete_event(id, calendar_id:, send_updates:)
       ya existe (lo usa el bot y el espejo de tareas agendadas); 404/410 = ya no estaba
     ✗ no hay ruta: events solo tiene index, create, update
```

Cómo se distinguen en la pantalla (`CalendarView.vue`):

```
  evento de Google CON tarea ligada  → extendedProps.agendaItem ≠ null  → es TAREA AGENDADA
  tarea agendada sin Google          → id «agenda-N», agendaItem        → es TAREA AGENDADA
  evento de Google SIN tarea         → agendaItem = null (punteado)     → es EVENTO
  evento de un compañero             → solo lectura (otra ventana)      → no aplica
```

Regla clave: **si un evento tiene tarea agendada, nunca se borra el evento a pelo**. Se cancela
la tarea y ella se encarga de Google; si no, la tarea quedaría viva apuntando a un evento borrado.

---

## 3. Cómo quedaría

### 3.1 Tarea agendada

```
  ┌──────────────────────────────────────────────────────────┐
  │  Editar tarea agendada                               ✕   │
  │  …campos…                                                │
  │                                                          │
  │  [Cancelar tarea agendada] [Pasar a tarea]  [Cerrar] [Guardar]
  │   rojo, texto                                            │
  └──────────────────────────────────────────────────────────┘
            │ clic
            ▼
  CancelItemModal (la misma de Tickets), kind="meeting"
  ┌──────────────────────────────────────────┐
  │ ¿Prefieres reprogramarla?                │
  │        [Reprogramar]  [No, cancelarla]   │──► Reprogramar = vuelve a la ventana
  ├──────────────────────────────────────────┤     de editar (cambiar la hora)
  │ Motivo        [ catálogo        ▾ ]      │
  │ Comentario    [                   ]      │  («Otro» lo pide)
  │ Tiempo        [   ] min                  │  (obligatorio si ya se trabajó)
  │ ○ Solo esta   ○ Toda la serie            │  (si es de una serie)
  │ ☑ Avisarle al cliente                    │  (si tiene contacto, organización o caso)
  │                    [Volver] [Cancelar]   │
  └──────────────────────────────────────────┘
            │
            ▼
  PATCH /agenda_items/:id { status:'cancelled', … }   ← ya existe
            │
            ├─ la tarea queda «Cancelada» con su motivo (historial en el caso)
            ├─ su evento sale de Google (y de los participantes)
            ├─ aviso a participantes (Cases::Meetings::Participants)
            └─ desaparece del calendario (index no lista canceladas) → recargar
```

Quién ve el botón:

```
  responsable de la tarea (participating = false)         → sí
  participante (otro es el responsable)                   → no; ya tiene «No puedo ir»
  tarea ya realizada / no asistió / cancelada             → no (son de solo lectura)
  caso cerrado (frozen)                                   → no (el servidor lo rechaza)
```

### 3.2 Evento de Google (sin tarea)

```
  ┌──────────────────────────────────────────────────────────┐
  │  Editar evento                                       ✕   │
  │  …campos…                                                │
  │  [Eliminar evento]                      [Cerrar] [Guardar]│
  └──────────────────────────────────────────────────────────┘
            │ clic: confirmación DENTRO de la misma ventana (como «Pasar a tarea»)
            ▼
  ┌──────────────────────────────────────────────────────────┐
  │ ¿Eliminar «Junta con proveedor»?                          │
  │ Se borra de tu Google Calendar.                           │
  │ ○ Solo este   ○ Toda la serie        (si se repite)       │
  │ ☑ Avisar a los 3 invitados           (si tiene invitados) │
  │                            [Volver]  [Eliminar]           │
  └──────────────────────────────────────────────────────────┘
            │
            ▼
  DELETE /google_calendar/events/:id?calendar_id=&scope=one|all&notify=true   ← NUEVO
            │
            ▼
  Servidor
   1. get_event (con MI conexión) → ¿existe?, ¿soy organizador?, ¿es de una serie?
   2. ¿lo usa una tarea agendada (CaseMeeting.google_event_id)? → 409 «Es una tarea
      agendada: cancélala» (no se borra; protege la regla clave)
   3. scope=all → borra el maestro (recurringEventId); one → solo esta ocurrencia
   4. notify → sendUpdates=all ; si no → none
   5. ¿era la cita que agendó el bot (ContactTracking.appointment_event_id)? → ver D3
            │
            ▼
  quita el evento de la pantalla al momento y recarga
```

Si **no soy el organizador** (me invitaron):

```
  Botón dice «Quitar de mi calendario» y no hay casilla de avisar.
  Google solo lo quita de MI calendario; el organizador y los demás lo conservan.
  (comportamiento exacto a medir en F0)
```

### 3.3 Colores de compañeros

Hoy (`components/GoogleCalendar/agentColor.js`):

```
  color = PALETA[ agent_id % 6 ]      letra = blanca siempre (lo pone FullCalendar)
   ✗ con más de 6 compañeros se repiten (#1 y #7 iguales)
   ✗ en verde limón / cian la letra blanca casi no se lee
   ✗ no se puede escoger
```

Cómo quedaría:

```
  Calendarios
  ▾ Compañeros
     ■ Andres Liverio      ●  ⚙ ──┐
     ■ Jose Luis              ⚙   │ clic
                                  ▼
          ┌──────────────────────────────────┐
          │ Color de Andres Liverio          │
          │ Fondo   ● ● ● ● ● ● ● ● ● ●      │  (la paleta de mis calendarios)
          │ Letra   ◉ Automática  ○ Blanca   │
          │         ○ Negra                  │
          │ Muestra ┌──────────────────────┐ │
          │         │ Andres · Junta 10:00 │ │  (se ve en vivo)
          │         └──────────────────────┘ │
          │ [Restablecer]  [Cancelar][Guardar]│
          └──────────────────────────────────┘
```

v1.3 (pedido del usuario): es una **ventana** nativa (`woot-modal`, molde de AddAgent, sin
scroll) que se abre con el icono de **configurar (⚙)**. Se escoge, se ve la vista previa y se
guarda con «Guardar» («Cancelar» no cambia nada; «Restablecer» solo si ya había un color).

```
  escojo color
      │
      ▼
  ui_settings del agente (preferencias del sistema, ya existen; viajan con mi usuario)
      calendar_coworker_colors: { "4": { bg: "#0ea5e9", text: "auto" }, … }
      │
      ▼
  colorDe(agente) = mi elección ‖ PALETA[agent_id % 6]   (helper agentColor.js)
  letraDe(agente) = blanca/negra según el contraste del fondo, o la que escogí
      │
      ├─ cuadrito del panel Compañeros
      ├─ eventos del compañero en el calendario (fondo, borde y letra)
      └─ franjas de «ocupado» de fondo (el mismo color con transparencia)
```

- **Es mío:** cada agente pinta a sus compañeros como quiera; nadie más lo ve y no se manda a Google.
- **Automática** = negro si el fondo es claro, blanco si es oscuro (contraste WCAG, como en
  los temas del dashboard). Es la opción por defecto, así que con solo este punto la letra ya
  se lee bien en todos los colores aunque nadie escoja nada.
- Sin servidor nuevo: `ui_settings` ya se guarda con `updateUISettings` (perfil).

---

## 4. Decisiones (recomendación primero) — ✅ confirmadas las 7 recomendaciones (26/11/2026)

| # | Pregunta | Recomendación | Alternativa |
|---|---|---|---|
| D1 | ¿La tarea agendada se **cancela** o se **borra**? | **Cancelar** (con motivo, queda historial; es lo que pide el sistema en todos lados). Borrar sigue solo para errores de captura donde ya existe. | Ofrecer también «Eliminar» dentro de las primeras 24 h |
| D2 | El botón de abajo «Cancelar» (cierra la ventana) junto a «Cancelar tarea agendada» confunde | **Renombrarlo a «Cerrar»** al editar | Dejarlo igual |
| D3 | Se elimina desde el calendario el evento de una cita que agendó el bot | **Limpiar la cita del seguimiento** (como cuando el cliente la cancela: campos de cita en blanco + nota privada «Cita eliminada desde el calendario por X»), sin mensaje al cliente | Bloquear y pedir que se cancele desde la conversación |
| D4 | «Avisar a los invitados» al eliminar un evento | **Palomeado por defecto** (Google avisa por correo) | Sin palomear |
| D5 | Eventos de calendarios que no son el principal (los palomeados en «Calendarios») | **Sí**, si Google me deja (si no tengo permiso de cambios Google responde 403 → «No tienes permiso para borrar en ese calendario») | Solo el principal |
| D6 | Paleta de fondo para compañeros | **La misma paleta de mis calendarios** (10 colores), para que todo se vea parejo | Selector libre de cualquier color |
| D7 | Letra | **Automática / Blanca / Negra** (por defecto Automática) | Selector libre de cualquier color |

---

## 5. Fases

### F0 — Medir en Google (Admin #1 y Andres #4, cuenta 2)
Antes de programar, con eventos de prueba que se borran al terminar:
- borrar un evento propio con invitado → ¿llega aviso con `sendUpdates=all`? ¿y con `none`?
- borrar como **invitado** (no organizador) → ¿desaparece solo de mi calendario? ¿qué ve el organizador?
- serie: borrar una ocurrencia (id `base_2026…`) vs el maestro (`recurringEventId`)
- calendario compartido conmigo como «Ver detalles» → confirmar el 403

#### ✅ F0 hecha (26/11/2026) — resultados

Script de medición (no queda en el repo) con Admin #1 y Andres #4 de la cuenta 2; eventos
«[F0 prueba]» del viernes 27 en la madrugada, **todos borrados al terminar** (quedan 0 en ambos).

```
  Caso                                         Resultado
  ───────────────────────────────────────────  ─────────────────────────────────────────────
  A  organizador borra, sendUpdates=none        OK; se borra
  B  organizador borra, sendUpdates=all         OK; se borra (aviso por correo: ver nota 2)
  C  invitado borra su copia                    NO MEDIBLE: el invitado no tiene el evento en
                                                su calendario (404) hasta aceptar por correo
                                                (ver nota 1)
  D  serie diaria ×3
     · DELETE de una ocurrencia (id base_2026…) OK → esa queda status=cancelled, el resto sigue
     · PATCH status=cancelled de una ocurrencia OK → igual que DELETE
     · DELETE del maestro (recurringEventId)    OK → maestro cancelled = toda la serie
  E  calendario de solo lectura (festivos MX)   403 reason=virtualCalendarManipulation
                                                «This calendar is read-only.»
     (los 4 calendarios de Admin son owner; no hay uno «reader» propio para probar)
  F  borrar algo que ya no está                 OK (404/410 = :already_gone, no truena)
```

Notas que cambian el diseño:
1. **Invitaciones sin aceptar no están en el calendario del invitado.** En ambas direcciones
   (Admin→Andres y Andres→Admin) el evento da 404 al invitado hasta que acepta desde el correo
   (protección de Google contra invitaciones de desconocidos). Consecuencia: el caso «me invitaron»
   (`organizer.self ≠ true`) solo aparece en el calendario **después de aceptar**. El botón
   «Quitar de mi calendario» se mantiene; su efecto exacto se mide en F5 (paso 5) aceptando
   antes una invitación.
2. **Correos:** A, B y C mandaron invitación a Andres (`sendUpdates=all` al crear). Al borrar,
   solo B (`sendUpdates=all`) debe haber mandado cancelación. Para confirmarlo, en el Gmail de
   Andres deben verse 3 invitaciones «[F0 prueba] …» y **una sola** cancelación (la de «B»).
   Se pueden borrar esos correos.
3. **«Solo este» de una serie:** se usa `cancel_instance` (PATCH status=cancelled), que es lo
   que ya hace el sistema en las tareas agendadas; DELETE da lo mismo, pero se sigue la
   convención. **«Toda la serie»** = `delete_event(recurringEventId)`.
4. **403:** se muestra «No tienes permiso para borrar en ese calendario» (`no_permission`),
   no el texto en inglés de Google.
5. `list_calendars` entrega llaves símbolo (`:access_role`): si en F3 se esconde el botón en
   calendarios de solo lectura, leer esa llave (los eventos de festivos sí se muestran).

### F1 — Servidor: eliminar evento de Google
- Ruta `resources :events, only: [:index, :create, :update, :destroy]`.
- `EventsController#destroy`: pasos 1–5 de §3.2; responde `{ deleted: true, scope: }` o el
  motivo legible (`google_calendar_delete.*` en es/en: `linked_to_agenda_item`, `no_permission`,
  `not_found`).
- D3: si coincide con `ContactTracking.appointment_event_id` → limpiar campos de cita + nota privada.
- Specs de request: propio, con aviso / sin aviso, serie one/all, ligado a tarea (409),
  sin permiso (403 de Google), ya no estaba (404 = ok), cita del bot.

#### ✅ F1 hecha (26/11/2026)

**Qué se hizo**
- `app/services/google_calendar_event_deleter.rb` (nuevo): toda la regla de borrado.
- `EventsController#destroy` + ruta `DELETE /api/v1/accounts/:id/google_calendar/events/:event_id`.
- Textos `google_calendar_delete.*` en `config/locales/{es,en}.yml`.

**Cómo funciona**

```
  DELETE …/events/:id?calendar_id=&scope=one|all&notify=true|false
     │
     ▼
  get_event (con MI conexión)
     ├─ 404/410 ............................. 200 { deleted: true, scope: 'one' }
     ├─ ligado a tarea agendada o su serie .. 409 { reason: 'linked_to_agenda_item' }
     │   (case_meetings.google_event_id o case_meeting_series.google_event_id = id o recurringEventId)
     ▼
  ¿organizer.self y notify? → sendUpdates=all : none   (invitado: nunca avisa)
     ├─ scope=all y es de serie → delete_event(recurringEventId)       → scope 'all'
     ├─ es de serie             → cancel_instance(id)  (PATCH cancelled)
     └─ suelto                  → delete_event(id)
     ▼
  ¿ContactTracking.appointment_event_id = id (misma cuenta)?  (D3)
     → cita en blanco (appointment_at/event_id/calendar_id/calendar_gid)
     → ai_context «🗑️ [CITA ELIMINADA] <agente> eliminó la cita desde el calendario.»
     → nota privada en la conversación, firmada por quien borró; al cliente no se le escribe
     (si esto falla, el evento ya se borró: igual responde 200)
     ▼
  200 { deleted: true, scope }
  errores: 403 de Google → 403 «No tienes permiso para borrar en ese calendario»
           otro         → 422 «Google no pudo borrar el evento. Inténtalo de nuevo.»
```

**Pila de pruebas**
- `spec/controllers/api/v1/accounts/google_calendar/events_destroy_spec.rb` (10): propio con
  aviso; sin aviso y en otro calendario; invitado nunca avisa; serie «Solo este» y «Toda la
  serie»; ligado a tarea (409); 403 traducido; ya no estaba; cita del bot liberada con nota
  privada; no toca citas de otra cuenta.
- Junto con el resto del calendario y tareas agendadas: **59 ejemplos, 0 fallas**
  (`POSTGRES_DATABASE=chatwoot_test`). Rubocop: archivos nuevos limpios; `events_controller.rb`
  conserva sus 19 faltas previas (ninguna nueva).
- **En vivo con Admin #1** (sin invitados, sin correos): suelto → cancelled; «Solo este» → esa
  ocurrencia cancelled y las otras siguen; «Toda la serie» → maestro cancelled; repetir → ok.
  Quedan 0 eventos de prueba.

**Cómo pedírselo al Asistente**
«Elimina el evento X de mi calendario» → `DELETE …/google_calendar/events/<id>`; si responde
409 es una tarea agendada y se cancela con `PATCH /agenda_items/:id { status: 'cancelled' }`.

### F2 — Pantalla: cancelar tarea agendada
- `item_json` agrega `series` (si pertenece a una serie) y `has_client`.
- `CreateEventModal.vue`: botón «Cancelar tarea agendada» (reglas de §3.1) → abre
  `CancelItemModal` kind="meeting"; `reschedule` regresa a la ventana; `submit` →
  `AgendaItemsAPI.updateItem(id, { status: 'cancelled', … })`; aviso al cliente con
  `CANCEL_ITEM.NOTICE_SENT / NOTICE_FAILED`; emite `created` (recarga) y cierra.
- D2: «Cerrar» al editar.

#### ✅ F2 hecha (26/11/2026)

**Qué se hizo**
- `agenda_items_controller.rb#item_json` agrega `series` (si la tarea es de una serie).
- `CreateEventModal.vue`: botón rojo **«Cancelar tarea agendada»** a la izquierda (junto a
  «Pasar a tarea»), `canCancelItem()`; el botón de abajo dice **«Cerrar»** al editar (D2,
  `closeLabel`). Emite `cancelItem` con la tarea.
- `GoogleCalendarView.vue`: `CancelItemModal` (la misma de Tickets) + `openCancelItem`,
  `rescheduleInstead`, `submitCancel`.
- i18n `GOOGLE_CALENDAR.EDIT_EVENT.{CLOSE, CANCEL_ITEM, CANCEL_ITEM_DONE}` es/en.

**Cómo funciona**

```
  Ventana del evento (tarea agendada, soy responsable, status scheduled)
     [Cancelar tarea agendada] ──emit cancelItem──► GoogleCalendarView
                                                    · guarda el evento (para volver)
                                                    · cierra la ventana del evento
                                                    · abre CancelItemModal kind=meeting
                                                      item = tarea + has_client (contacto,
                                                      organización o caso) + series
        ┌──────────── «Reprogramar» ◄──────────────────┤
        ▼                                              │ «No, cancelarla» → motivo…
  vuelve a abrir la ventana del MISMO evento           ▼
                                   PATCH /agenda_items/:id { status:'cancelled', reason_id,
                                         comment, minutes, scope, notify_client }
                                         ├─ ok → aviso «Tarea agendada cancelada» (o
                                         │        «Se avisó al cliente» / «no se pudo avisar»)
                                         │        y recarga el calendario (ya no sale)
                                         └─ error → la ventana sigue abierta con el motivo
                                                    (p. ej. caso cerrado, falta motivo)
```

No es una ventana encima de otra: se cambia de una a la otra.
Quién lo ve: responsable y tarea agendada (`scheduled`). Participante → no (tiene «No puedo
ir»); realizada / no asistió / cancelada → no. Caso cerrado: el botón sale, pero el servidor
responde «Ticket cerrado…» y se muestra en la ventana de cancelar.

**Pila de pruebas**
- Vitest (26 en las carpetas del calendario, 0 fallas):
  `components/GoogleCalendar/specs/CreateEventModal.cancelItem.spec.js` (quién ve el botón,
  «Cerrar»/«Cancelar») y
  `routes/dashboard/settings/googleCalendar/specs/GoogleCalendarView.cancelItem.spec.js`
  (abrir con/sin cliente, Reprogramar vuelve al mismo evento, manda `status: 'cancelled'` con
  el motivo y recarga, aviso al cliente, error deja la ventana abierta).
- RSpec `agenda_items_spec.rb` +2: cancelar con motivo (queda `cancel_reason`, `series:
  false`) y sin motivo → 422. Con calendario y cancelaciones: **55 ejemplos, 0 fallas**.
- eslint: archivos nuevos limpios; los que ya existían, mismas faltas previas (GoogleCalendarView 12,
  en/googleCalendar.js 7), ninguna en líneas nuevas. webpack: «Compiled successfully».

**Cómo pedírselo al Asistente**
«Cancela la tarea agendada X» → `PATCH /agenda_items/:id { status: 'cancelled', reason_id }`
(motivos en `GET /task_outcomes?purpose=cancel`).

### F3 — Pantalla: eliminar evento
- `api/googleCalendar.js` `deleteEvent(id, params)`; store `deleteEvent` (lo quita de `events`
  al momento; si falla, lo regresa y muestra el error).
- `CreateEventModal.vue`: botón «Eliminar evento» / «Quitar de mi calendario», confirmación
  en línea con serie y avisar a invitados (§3.2).
- i18n es/en (`GOOGLE_CALENDAR.DELETE_EVENT.*`, `GOOGLE_CALENDAR.CANCEL_ITEM.*`).
- Vitest: qué botón sale en cada caso (tarea, evento propio, invitado, participante, cerrada).

#### ✅ F3 hecha (26/11/2026)

**Qué se hizo**
- `CalendarView.vue`: cada evento de Google lleva `organizerSelf` y `recurringEventId`.
- `api/googleCalendar.js#deleteEvent(id, { calendar_id, scope, notify })`.
- Store `deleteEvent`: lo quita de la pantalla al momento (con «Toda la serie», todas sus
  fechas); si el servidor falla, lo regresa y el error sube con su motivo.
- `CreateEventModal.vue`: botón rojo **«Eliminar evento»** (o **«Quitar de mi calendario»** si
  me invitaron) a la izquierda; confirmación en línea con «Solo este / Toda la serie» (si se
  repite) y «Avisar a los invitados (N)» (si soy organizador y hay invitados).
- i18n `GOOGLE_CALENDAR.DELETE_EVENT.*` es/en.

**Cómo funciona**

```
  Ventana del evento (evento de Google, sin tarea agendada, calendario mío o «Hacer cambios»)
     [Eliminar evento]                                   [Cerrar] [Guardar]
          │ clic
          ▼
     ┌ ¿Eliminar «Junta»? ─────────────────────────────┐
     │ Se borra de tu Google Calendar.                  │
     │ ○ Solo este  ○ Toda la serie        (si se repite)│
     │ ☑ Avisar a los invitados (2)        (organizador) │
     │                           [Volver] [Eliminar]    │
     └──────────────────────────────────────────────────┘
          │
          ▼
     store deleteEvent → sale de la pantalla ya → DELETE …/events/:id
          ├─ ok → «Evento eliminado» / «Se quitó de tu calendario», recarga y cierra
          └─ error → regresa a la pantalla, se muestra el motivo (p. ej. «Este evento es una
                     tarea agendada: cancélala…») y la ventana queda abierta
```

Quién ve el botón: evento de Google sin tarea ligada; no en tareas agendadas (esas tienen
«Cancelar tarea agendada»), ni en tareas solo del sistema, ni en calendarios de solo lectura
(`access_role` reader/freeBusyReader, p. ej. festivos). Invitado (`organizer.self ≠ true`): dice
«Quitar de mi calendario», sin casilla de aviso.

**Pila de pruebas**
- Vitest: `components/GoogleCalendar/specs/CreateEventModal.deleteEvent.spec.js` (8: cuándo
  sale, solo lectura, invitado, cuenta de invitados sin mí, qué manda, cuándo no avisa,
  alcance de serie, error no cierra) y `store/modules/specs/googleCalendar/deleteEvent.spec.js`
  (3: quita al momento y parámetros, serie entera vs una fecha, si falla regresa).
  Carpetas del calendario + store: **44 pruebas, 0 fallas**.
- eslint: los nuevos limpios; CreateEventModal 0, store 3 (previas), api 20 (19 previas + el
  `axios` global que tienen todos sus métodos). webpack: «Compiled successfully».

**Cómo pedírselo al Asistente**
Igual que F1: «Elimina el evento X» → `DELETE …/google_calendar/events/<id>`.

### F4 — Colores de compañeros
- `agentColor.js`: `agentColor(id, custom)` y `agentTextColor(bg, choice)` (contraste);
  la paleta pasa a un archivo compartido con la de calendarios (`AgendaWidget.vue`).
- Store/composable: leer y escribir `calendar_coworker_colors` en `ui_settings`.
- `AgendaWidget.vue`: botón ⋯ por compañero y menú flotante de §3.3 (muestra en vivo, Restablecer).
- `CalendarView.vue`: eventos del compañero con `backgroundColor`, `borderColor` y `textColor`;
  franjas de ocupado con el color escogido.
- Vitest: color por defecto, color escogido, letra automática negra sobre fondo claro y
  blanca sobre oscuro, Restablecer.

#### ✅ F4 hecha (26/11/2026)

**Qué se hizo**
- `components/GoogleCalendar/calendarPalette.js` (nuevo): la paleta de 10 colores, ahora
  compartida por «Mis calendarios» y compañeros (D6).
- `agentColor.js`: `agentColor(id, custom)`, `agentTextColor(id, custom)`, `autoTextColor(bg)`
  (contraste WCAG: blanca `#ffffff` u oscura `#1f2937`, la que más contraste dé),
  `coworkerColorsFrom(uiSettings)`, `COWORKER_COLORS_KEY = 'calendar_coworker_colors'`.
- `CoworkerColorModal.vue` (nuevo; v1.3 sustituye al menú flotante): ventana nativa con
  encabezado y descripción, fondo, letra Automática/Blanca/Negra (D7), vista previa,
  Restablecer / Cancelar / Guardar.
- `AgendaWidget.vue`: botón ⚙ («Configurar color») en cada compañero que te comparte; una sola
  ventana para todos; «Guardar» hace `updateUISettings` sin tocar las demás preferencias;
  Restablecer quita solo a ese compañero.
- `CalendarView.vue`: eventos del compañero con `backgroundColor`, `borderColor` y `textColor`;
  franjas de ocupado con el color escogido; se repinta al momento (watch `coworkerColors`).
- i18n `GOOGLE_CALENDAR.COWORKERS.COLOR.*` es/en.

**Cómo funciona**

```
  ⚙ de Andres → CoworkerColorModal → Guardar → save { bg, text }
        │
        ▼
  dispatch('updateUISettings') — pinta al momento (commit antes de la API) y guarda en
  PUT /profile { ui_settings: { …las demás…, calendar_coworker_colors: { "4": { bg, text } } } }
        │                                        (el perfil acepta el mapa: permit ui_settings: {})
        ▼
  getters.getUISettings → coworkerColors (panel y calendario) → cuadrito, eventos y franjas
  Sin elección → color de siempre (PALETA[agent_id % 6]) con letra Automática.
```

Es solo mío: va en mis preferencias de usuario (me sigue en cualquier navegador), no en Google
ni en las de mis compañeros. El ⚙ sale solo en compañeros que me comparten algo.

**Pila de pruebas**
- Vitest `components/GoogleCalendar/specs/coworkerColors.spec.js` (10): color de siempre, color
  escogido, letra automática (negra en verde limón y cian, blanca en oscuros), escoger no
  guarda y «Guardar» manda fondo y letra, vista previa con el contraste correcto,
  «Restablecer» solo con color propio, Guardar/Restablecer cierran, guardar sin borrar otras
  preferencias, Restablecer solo uno, el calendario pinta fondo/borde/letra.
  Carpetas del calendario + store: **54 pruebas, 0 fallas**.
- eslint: nuevos limpios; AgendaWidget 28 (antes 30: salió la paleta mal formateada),
  CalendarView 0. webpack: «Compiled successfully».

**Cómo pedírselo al Asistente**
«Pon a Andres en azul en mi calendario» → `ui_settings.calendar_coworker_colors["<id>"] =
{ bg: '#0ea5e9', text: 'auto' }` del agente que lo pide (PUT /profile).

### F5 — Pila de pruebas en navegador (cuenta 2)
1. Crear tarea agendada con Andres de participante → Cancelar con motivo → sale del calendario
   de ambos y de Google; queda «Cancelada» en Tickets → Tareas.
2. Lo mismo con «¿Prefieres reprogramarla?» → Reprogramar → cambia la hora.
3. Tarea de una serie → «Toda la serie».
4. Evento propio con un invitado → Eliminar con aviso → llega correo de cancelación.
5. Evento donde me invitaron → «Quitar de mi calendario».
6. Evento que es una tarea agendada no debe mostrar «Eliminar evento» (solo cancelar).
7. Compañeros → ⚙ de Andres → escoger fondo y letra → Guardar → cambian el cuadrito, sus
   eventos y sus franjas; recargar la página y abrir en otro navegador → sigue igual.
   Cancelar → no cambia nada.
8. Sin escoger nada, los compañeros en verde limón / cian ya se leen con letra negra.
9. Restablecer → vuelve al color de antes. Andres no ve el cambio en su pantalla.

---

## 6. Fuera de alcance
- Eliminar eventos en el calendario de un compañero (D3 del plan anterior: crear sí, editar no).
- Deshacer una cancelación desde el calendario (se reabre desde el caso, como hoy).
- Borrar varios eventos a la vez.
