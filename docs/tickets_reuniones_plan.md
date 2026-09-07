# Plan — Reuniones y series de reuniones en Tickets (MGCI)

> Rama destino: `feat/tickets` · Estado: **solo plan, sin implementar**
> Fecha: 2026-08-10

## 1. Objetivo

Que desde el detalle de un ticket —en el mismo lugar donde hoy se ven y se agregan
las notas y las tareas— se pueda **agendar una reunión con el cliente**, o una
**serie de reuniones tipo calendario** (cada martes 10:00 × 8 semanas), y que esa
reunión quede registrada en el ticket **y** en el Google Calendar del agente, con
invitación por correo al contacto y liga de Meet.

### Decisiones ya tomadas

| Pregunta | Decisión |
|---|---|
| Arquitectura | **Opción B**: reunión nativa en BD + espejo opcional a Google Calendar |
| Invitados | **Al cliente** (contacto del ticket) + agentes; correo de invitación y Meet |
| Tipo de serie | **Calendario clásico** (RRULE: cada martes 10:00, hasta fecha/N ocurrencias) |
| Alcance | **Del ticket o de una tarea**: `case_task_id` **opcional** — igual que las notas internas (`add_internal_note!(case_task:)`) |
| Configuración | **Cero pantallas nuevas de ajustes.** Ningún feature flag nuevo, ningún setting por cuenta ni por agente. Todo default se deriva de los datos del ticket (§10) |

---

## 2. Terreno actual (lo que se reaprovecha tal cual)

```
YA EXISTE                                          SE REAPROVECHA PARA
─────────────────────────────────────────────────  ──────────────────────────────
UserCalendarIntegration (OAuth por agente+cuenta)   organizador de la reunión
  tokens jsonb, refresh automático
GoogleCalendarService                               crear/mover/borrar el evento
  create_event / update_event / delete_event          → le FALTA recurrencia y Meet
  free_busy / list_calendars / account_timezone     sugerir horarios libres
  post(..., query: { sendUpdates: 'all' })          ← YA manda correo a invitados
                                                      de cualquier dominio (.ics)
Feature flag `google_calendar`                      gating del espejo
Feature flag `case_management`                      gating del módulo
case_events + JourneyView                           bitácora de la reunión
TicketNotes.vue / TicketTasks.vue                   patrón de pestaña + modal
  @addNote / @viewNotes (fila → pestaña filtrada)   patrón de acción por fila
contact_tracking_response_analyzer_job.rb:1242      precedente vivo de creación
                                                      de eventos reales desde otro módulo
```

### Los tres huecos reales

1. **No hay persistencia de reuniones.** Hoy un evento vive solo en Google.
2. **`GoogleCalendarService` no manda `RRULE`** → sin esto no hay serie.
3. **No genera liga de Meet** (`conferenceData`), que es lo que se espera de una
   reunión con cliente.

> Nota de arquitectura relevante: **las notas internas NO tienen tabla propia**,
> viven en `case_events` con `event_type: :internal_note` y un `sequence` en el
> payload. Las reuniones **sí necesitan tabla**: guardan ids de Google, estado de
> sincronización y regla de recurrencia — cosas que un evento de bitácora
> inmutable no puede sostener.

---

## 3. Modelo de datos

```
              case_tickets
                   │ 1
                   │
                   │ N
            ┌──────┴───────────┐
            │  case_meetings   │────── case_task_id (opcional, folio T00N)
            │  folio R001…     │────── organizer_id → users
            └──────┬───────────┘        google_event_id
                   │ N                  google_calendar_id
                   │                    sync_status / sync_error
                   │ 1
        ┌──────────┴────────────┐
        │  case_meeting_series  │  ← la SERIE: guarda el RRULE y el id del
        │  folio S01…           │    evento recurrente maestro de Google
        └───────────────────────┘

  reunión suelta  →  case_meetings con series_id NULL
  serie           →  1 case_meeting_series  +  N case_meetings (ocurrencias)
```

### 3.1 Tabla `case_meetings`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL | FK |
| `case_ticket_id` | bigint NOT NULL | FK, `dependent: :destroy` desde el ticket |
| `case_task_id` | bigint NULL | FK ON DELETE nullify — la reunión sobrevive al borrado de la tarea |
| `case_meeting_series_id` | bigint NULL | FK ON DELETE cascade |
| `organizer_id` | bigint NULL | FK users ON DELETE nullify — dueño del calendario |
| `sequence` | integer | consecutivo estable por ticket → folio `R001` |
| `title` | string NOT NULL | máx 255 |
| `description` | text | |
| `starts_at` / `ends_at` | datetime NOT NULL | siempre en UTC en BD |
| `time_zone` | string | IANA de la cuenta al momento de crear (`account_timezone`) |
| `location` | string | presencial |
| `meeting_url` | string | liga de Meet devuelta por Google |
| `status` | integer NOT NULL default 0 | enum, ver abajo |
| `attendee_emails` | jsonb default `[]` | snapshot de a quién se invitó |
| `notify_client` | boolean default true | si false, no se invita al contacto |
| `google_event_id` | string | id de la instancia en Google |
| `google_calendar_id` | string | normalmente `primary` |
| `sync_status` | integer NOT NULL default 0 | enum: `pending / synced / failed / local_only` |
| `sync_error` | text | último error de la API, para mostrarlo en la fila |
| `reconciled_at` | datetime | última relectura desde Google — *throttle* de §5 |
| `cancelled_at`, `cancelled_by_id` | datetime / bigint | firma derivada, no del cliente |
| `held_at`, `held_by_id` | datetime / bigint | firma derivada, no del cliente |

**Índices:** `(case_ticket_id, starts_at)`, `(case_ticket_id, sequence)`,
`(case_task_id)`, `(case_meeting_series_id)`, `(account_id, starts_at)`
(este último para la futura bandeja de reuniones a nivel cuenta),
`(google_event_id)`.

```ruby
enum status: { scheduled: 0, held: 1, no_show: 2, cancelled: 3, rescheduled: 4 }
enum sync_status: { pending: 0, synced: 1, failed: 2, local_only: 3 }
```

- `local_only` = la reunión existe solo en MGCI (el agente no tiene Calendar
  conectado, o la cuenta no tiene el flag `google_calendar`). **No es un error**:
  es el modo degradado válido de la Opción B.
- `held` / `no_show` los marca el agente al cerrar la reunión; disparan la
  oferta de minuta (§6.3).
- Igual que en `CaseTask#track_completion`, el *quién/cuándo* de `held` y
  `cancelled` se **deriva del cambio de estado** en un `before_save`, nunca se
  acepta del cliente.

### 3.2 Tabla `case_meeting_series`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id`, `case_ticket_id` | bigint NOT NULL | FK |
| `case_task_id` | bigint NULL | se hereda a las ocurrencias al generarlas |
| `organizer_id` | bigint NULL | FK users |
| `sequence` | integer | folio `S01` por ticket |
| `title`, `description` | | plantilla de cada ocurrencia |
| `recurrence_rule` | string | el RRULE crudo: `RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8` |
| `freq` | integer | enum `daily/weekly/monthly` — para poder re-renderizar el formulario |
| `interval` | integer default 1 | "cada N semanas" |
| `by_day` | jsonb default `[]` | `["TU","TH"]` |
| `starts_at`, `ends_at` | datetime | primera ocurrencia (define hora y duración) |
| `until_at` | datetime NULL | fin por fecha |
| `count` | integer NULL | fin por número de ocurrencias |
| `time_zone` | string | |
| `google_event_id` | string | **el evento maestro recurrente** |
| `google_calendar_id`, `sync_status`, `sync_error` | | igual que arriba |
| `cancelled_at`, `cancelled_by_id` | | cancelar la serie completa |

> `until_at` y `count` son mutuamente excluyentes; una validación lo garantiza.
> Si ninguno viene, se rechaza: **no se permiten series infinitas** (generarían
> ocurrencias sin fin en BD).

### 3.3 Nuevos `case_events` (al FINAL del enum, sin reordenar)

```ruby
meeting_scheduled: 30,   # se agendó reunión o serie
meeting_updated:   31,   # se movió de fecha/hora
meeting_cancelled: 32,   # se canceló (una o toda la serie)
meeting_held:      33    # se marcó realizada / no asistió
```

Payload sugerido: `{ meeting_id:, sequence:, title:, starts_at:, series_sequence:, scope: 'one'|'all' }`.
`JourneyView.vue → payloadSummary()` necesita un caso nuevo por cada uno.

---

## 4. Backend

### 4.1 Extensión de `GoogleCalendarService`

Tres adiciones quirúrgicas, sin tocar las firmas existentes (hay llamadores vivos
en `events_controller.rb` y en el job de seguimientos — **no romperlos**):

```ruby
# create_event: dos kwargs nuevos, ambos opcionales
def create_event(..., recurrence: nil, with_meet: false)
  ...
  body[:recurrence] = Array(recurrence) if recurrence.present?   # ["RRULE:FREQ=WEEKLY;..."]
  if with_meet
    body[:conferenceData] = {
      createRequest: {
        requestId: SecureRandom.uuid,
        conferenceSolutionKey: { type: 'hangoutsMeet' }
      }
    }
  end
  post(..., query: { sendUpdates: 'all', conferenceDataVersion: with_meet ? 1 : 0 })
end

# Ocurrencias reales de un evento recurrente (Google las materializa él)
def list_instances(event_id, calendar_id: 'primary', max_results: 250)

# Cancelar UNA ocurrencia de una serie: NO es DELETE, es PATCH status=cancelled
def cancel_instance(instance_id, calendar_id: 'primary')
```

⚠️ `conferenceDataVersion: 1` es **obligatorio** para que Google cree el Meet;
sin ese query param la API acepta el body y devuelve el evento **sin** liga, en
silencio. La `meeting_url` sale de `event.dig('conferenceData','entryPoints')`
con `entryPointType == 'video'`, o del `hangoutLink` de respaldo.

### 4.2 Servicios nuevos

```
app/services/cases/meetings/
├── scheduler_service.rb    crea la reunión suelta: valida, persiste,
│                           encola el espejo, registra case_event
├── series_service.rb       crea la serie: arma el RRULE, persiste el padre,
│                           espeja el maestro, expande ocurrencias
├── rrule_builder.rb        {freq, interval, by_day, until/count, tz} → RRULE
├── reconcile_service.rb    relee desde Google al abrir la pestaña (§5);
│                           solo lectura, con throttle y tope
└── google_mirror_service.rb  única puerta a GoogleCalendarService: decide
                             local_only vs synced, captura errores en sync_error,
                             y resuelve `sendUpdates` a partir del diff (§10.2b)
```

`google_mirror_service` es el punto donde se concentra **toda** la tolerancia a
fallas: si el agente no tiene integración, si el flag `google_calendar` está
apagado, o si Google responde error, la reunión **igual queda creada** en MGCI
con `sync_status` en `local_only` / `failed`. Ese es el corazón de la Opción B.

### 4.3 Expansión de ocurrencias

Google ya materializa las instancias del RRULE; **no reimplementamos el
calendario**. El flujo es: crear maestro → `list_instances` → persistir una fila
`case_meetings` por instancia con su `google_event_id` propio.

```
  POST /series
      │
      ├─► RRuleBuilder → "RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8"
      │
      ├─► case_meeting_series (BD)          ── siempre, aunque Google falle
      │
      ├─► create_event(recurrence:, with_meet: true)   ── 1 evento maestro
      │       └─► google_event_id del maestro
      │
      └─► list_instances(maestro)  →  8 instancias
              └─► 8 × case_meetings (series_id, google_event_id de la instancia)

  Si Google falla:  la serie queda local_only y las 8 ocurrencias se generan
  con RRuleBuilder#expand (cálculo propio, mismo resultado de fechas),
  sin google_event_id. Reintentable después desde la UI ("Reintentar sync").
```

`RRuleBuilder#expand` (cálculo local de fechas) se necesita de todos modos para
el modo degradado y para la vista previa en el formulario ("se crearán 8
reuniones: 17 ago, 24 ago, …"). Tope duro: **100 ocurrencias**.

### 4.4 Job

`Cases::MeetingSyncJob` (Sidekiq) — hace el espejo fuera del request para que
agendar no dependa de la latencia de Google. Encolado por los servicios;
reintentos acotados; al terminar actualiza `sync_status` y emite el `case_event`.

### 4.5 API

```
resources :case_tickets do
  ...
  resources :case_meetings, only: [:index, :create, :update, :destroy], path: 'meetings' do
    member do
      patch :hold      # marcar realizada / no asistió
      patch :cancel    # scope: 'one' | 'all'
      post  :resync    # reintentar el espejo tras un fallo
    end
  end
  resources :case_meeting_series, only: [:create, :update, :destroy], path: 'meeting-series'
end
```

- `PATCH /meetings/:id` acepta `scope: 'one' | 'following' | 'all'` cuando la
  reunión pertenece a una serie (semántica estándar de calendario).
  **F3 implementa `one` y `all`; `following` queda diferido** — es el que obliga
  a partir el RRULE en dos y no vale su costo en la primera entrega.
- `GET /meetings` devuelve también `available_organizers` (agentes con Calendar
  conectado) para que la UI sepa si puede ofrecer el espejo.

**Autorización:** heredar exactamente el patrón de `case_tasks_controller.rb` y
`case_notes_controller.rb` (mismo `before_action`, mismo scoping por
`Current.account`). No inventar reglas nuevas.

---

## 5. Sincronización — reconciliación perezosa (sin webhooks, sin configuración)

```
  MGCI  ──────────────►  Google Calendar     escritura, en el momento (F2/F3)
  MGCI  ◄──────────────  Google Calendar     LECTURA al abrir la pestaña (F2)
```

El problema real: el agente mueve o borra la cita **desde su propio Google
Calendar** y MGCI se queda con la fecha vieja.

La solución cara sería `events.watch` (webhooks push, canales que caducan y hay
que renovar, endpoint público, secretos). Eso **sí** implicaría infraestructura y
configuración. **No se hace.**

En su lugar: **reconciliar al leer**. Cuando alguien abre la pestaña Reuniones de
un ticket, el backend ya tiene el token del organizador guardado — así que antes
de responder, relee esas reuniones desde Google y actualiza lo que cambió.

```
  GET /case_tickets/:id/meetings
        │
        ├─► ¿hay reuniones futuras con google_event_id y organizador conectado?
        │        │ no → responde tal cual (0 llamadas a Google)
        │        ▼ sí
        ├─► ReconcileService (tope 25, solo futuras, throttle 60 s por ticket)
        │        │
        │        ├─ Google dice otra hora      → actualiza starts_at/ends_at
        │        ├─ Google dice status=cancelled → marca cancelled
        │        ├─ Google responde 404/410    → ⚠ ver §5.1, NO cancelar a ciegas
        │        └─ Google falla               → deja la fila como está, sync_error
        │
        └─► responde la lista ya fresca
```

Propiedades que la hacen viable:

- **Cero configuración**: usa el OAuth que el organizador ya concedió.
- **Cero infraestructura**: no hay endpoint público, ni canales, ni renovación.
- **Costo acotado**: solo reuniones **futuras** y **no canceladas**, tope de 25 por
  lectura, y un *throttle* de 60 s por ticket (marca de tiempo `reconciled_at`)
  para que abrir la pestaña tres veces seguidas no dispare tres rondas.
- **Se ejecuta del lado del servidor con la integración del organizador**, no del
  que está mirando — mismo patrón que ya usa `agent_events` para leer el
  `free_busy` de otro agente.
- **Nunca escribe hacia Google.** Es estrictamente lectura: si hay conflicto,
  Google gana en fecha/hora/cancelación, porque es donde el humano acaba de tocar.

Por sí sola, esta solución no refleja el cambio hasta que alguien abre el ticket.
Eso se resuelve con push en **§12** — pero la reconciliación perezosa **no se
retira**: se queda como red de seguridad permanente (§12.5).

> Columna extra en `case_meetings`: `reconciled_at :datetime` (para el throttle).

### 5.1 Reconciliar una SERIE no es reconciliar N reuniones sueltas

Caso motivador: la reunión del **21 de agosto se arrastra al 24** desde Google
Calendar. En Google eso abre dos caminos distintos, y MGCI tiene que distinguirlos
o corrompe los datos.

**Camino A — "Este evento" (mover solo la ocurrencia).**
Google crea una *excepción*: la instancia cambia de `start`, gana un campo
`originalStartTime`… **y conserva su id**, porque el id de instancia se deriva del
arranque *original* (`{idMaestro}_20260821T220000Z`), no del nuevo. Es justo lo
que salva la reconciliación: nuestro `google_event_id` de `R002` sigue resolviendo.

```
  R002  google_event_id = master_20260821T220000Z   (no cambia nunca)
        starts_at  21 ago 16:00  ──reconcile──►  24 ago 16:00
```

**Camino B — "Todos los eventos" (mover la serie completa).**
Google reescribe el **maestro** y su RRULE. Las instancias se re-derivan de los
nuevos arranques originales, así que **los ids de instancia cambian**: los tres
`google_event_id` que teníamos guardados dejan de existir.

⚠️ **Aquí estaba el defecto del diagrama de arriba.** La regla ingenua
"404/410 → marca cancelled" convertiría un *reagendado de serie* en **tres
reuniones canceladas** en el ticket. Silenciosamente, y con el cliente aún citado
en Google. Corrección:

```
  reunión con case_meeting_series_id?
      │
      ├─ NO  → GET /events/{id}. 404/410 = borrada de verdad → cancelled ✔
      │
      └─ SÍ  → NUNCA consultar la instancia por id. Consultar el MAESTRO:
               list_instances(series.google_event_id)
                   │
                   ├─ maestro 404/410 → la serie sí se borró → cancelar todas ✔
                   │
                   └─ maestro vivo → re-emparejar sus instancias con nuestras
                      filas por `originalStartTime` (estable) y, si ya no
                      coincide, por orden cronológico:
                        · instancia presente  → actualizar fecha + id
                        · fila sin instancia  → esa sí está cancelada
                        · instancia sin fila  → alta (crecieron las ocurrencias)
```

Además de correcto, es **más barato**: una sola llamada resuelve las 3 reuniones
de la serie en vez de 3 llamadas por id.

### 5.2 Qué se ve en el ticket cuando Google gana

Al detectar el cambio, la reconciliación registra un `meeting_updated` en la
bitácora, con `origin: :system` (no fue un agente actuando en MGCI) y el rastro de
que vino de fuera:

```ruby
payload: { meeting_id:, sequence: 'R002', source: 'google',
           from: '2026-08-21T16:00', to: '2026-08-24T16:00' }
```

Eso lo hace visible en **Avance** (`JourneyView`) y en la fila de la pestaña
Reuniones. **Las notas no se tocan**: una minuta es contenido que escribe una
persona, y auto-generar una nota por cada arrastre de calendario llenaría de ruido
la pestaña Notas. Si al mover la reunión hace falta dejar constancia, se usa el
flujo de minuta que ya existe (§6.3).

Detalle fino sin costo: si la fecha nueva queda **después del vencimiento de la
tarea** a la que cuelga la reunión, la fila se marca visualmente. Es una
comparación de dos fechas que ya tenemos, no una configuración.

### 6.1 Dónde vive

```
[ Resumen ][ Avance ][ Notas 4 ][ Tareas 3 ][ Reuniones 2 ][ IA ]
                          │           │            │
                          │           │            └── TicketMeetings.vue (NUEVO)
                          │           │                tabla + modal, calcado de
                          │           │                TicketNotes.vue
                          │           │
                          │           └── fila de tarea T003, menú ⋮:
                          │                 Agregar nota        (ya existe)
                          │                 Agregar reunión     ← NUEVO
                          │                 Programar serie     ← NUEVO
                          │                 Ver reuniones       ← NUEVO
                          │
                          └── una nota puede ser la MINUTA de una reunión
```

Archivos:
- `app/javascript/dashboard/components/contacts/CaseTicket/TicketMeetings.vue` (nuevo)
- `.../CaseTicket/MeetingFormModal.vue` (nuevo — alta/edición, suelta o serie)
- `TicketDetail.vue`: registrar la pestaña en `detailTabs`, el `meetingCount`
  para el badge, y los handlers `@addMeeting` / `@viewMeetings` **espejando
  exactamente** `openNoteForTask` / `openNotesForTask` (líneas ~1077-1113),
  incluido el soporte de query string `?tab=meetings&task=N&compose=1`.
- `TicketTasks.vue`: tres entradas nuevas en el menú de fila, emitiendo eventos.

### 6.2 El modal

```
┌─ Nueva reunión ──────────────────────────────────────────┐
│  Título        [ Revisión de avance                    ] │
│  Tarea         [ T003 — Migrar buzón            ▾ ]      │  ← opcional
│  Fecha         [ 17/08/2026 ]  [ 10:00 ] – [ 11:00 ]     │
│  Organizador   [ Ana (Calendar conectado) ▾ ]            │
│                                                          │
│  ( ) Reunión única    (•) Serie                          │
│      ┌──────────────────────────────────────────────┐    │
│      │ Repetir  cada [1] [semana ▾]                 │    │
│      │ Días     [L][M][X][J][V][S][D]   ← M activo  │    │
│      │ Termina  (•) después de [8] reuniones        │    │
│      │          ( ) el [ 12/10/2026 ]               │    │
│      │ ▸ Se crearán 8: 17 ago, 24 ago, 31 ago, …    │    │  ← vista previa
│      └──────────────────────────────────────────────┘    │
│                                                          │
│  [x] Invitar al cliente  →  cliente@empresa.com          │
│  [x] Generar liga de Meet                                │
│  Otros invitados  [ + agregar agente ]                   │
│                                                          │
│  ⚠ Se enviará invitación por correo al cliente.          │
│                              [ Cancelar ]  [ Agendar ]   │
└──────────────────────────────────────────────────────────┘
```

Estados que el formulario debe manejar sin romperse:
- **Ticket sin contacto** (ticket interno, `origin: internal`): "Invitar al
  cliente" se deshabilita con la razón visible. La reunión se agenda igual.
- **Contacto sin email**: mismo tratamiento.
- **Ningún agente con Calendar conectado**: se oculta Meet, la reunión se crea
  `local_only`, con aviso — no se bloquea el alta.
- **Cuenta sin flag `google_calendar`**: todo el bloque de Google desaparece.

### 6.3 Cierre del círculo con las notas

Al marcar una reunión como *realizada*, se ofrece —no se impone— capturar la
minuta. Esa minuta se crea con el `add_internal_note!` que **ya existe**, con el
`case_task` de la reunión, de modo que aparece en la pestaña Notas filtrada por
esa tarea, exactamente donde ya se lee el avance.

```
  reunión R002 (tarea T003)  ──[ realizada ]──►  ¿Capturar minuta?
                                                       │
                                                       ▼
                              add_internal_note!(content:, case_task: T003)
                                                       │
                                                       ▼
                                        Notas · N014 · ligada a T003
```

### 6.4 i18n

Claves nuevas bajo `CASE_TICKETS.MEETINGS.*` en `es` **y** `en`.
Sin cadenas desnudas (bare-strings) en el `.vue`.

---

## 7. Fases

Criterio de orden: **que haya algo usable lo antes posible**, y que Google entre
solo cuando lo nativo ya funcione. F0–F2 no tocan Google en absoluto — se prueban
sin OAuth, sin cuota y sin mandarle correo a nadie.

```
  F0 ─► F1 ─► F2 ─────────────────────────────────►  usable sin Google
              │
              └─► F3 ─► F4 ─► F5 ─► F6 ─────────────►  con Google
                                     │
                                     └─► F7 (push)  ──►  tiempo real
```

| Fase | Contenido | Entregable verificable | Google |
|---|---|---|---|
| **F0** · Datos | Migraciones (2 tablas + 4 valores de enum al final), modelos, folios `R00N`/`S0N`, validaciones, `before_save` de firmas derivadas | consola: crear reunión y serie a mano | no |
| **F1** · API nativa | Controllers + rutas (§4.5) + `case_events` + `payloadSummary` en `JourneyView` | CRUD por API; la reunión aparece en Avance | no |
| **F2** · UI base | Pestaña Reuniones (`TicketMeetings.vue`), modal de alta, acciones en fila de tarea, minuta→nota (§6.3), i18n es/en | **primer entregable usable**: agendar y ver reuniones en el navegador | no |
| **F3** · Espejo | `GoogleCalendarService` (+Meet, +instances, +cancel_instance), `GoogleMirrorService`, `MeetingSyncJob`, `ReconcileService` (§5/§5.1), co-invitados (§10.3), `sendUpdates` por diff (§10.2b) | la cita llega al Calendar del agente y al correo del cliente con Meet; moverla en Google se refleja al reabrir | sí |
| **F4** · Series | `RRuleBuilder` (+`expand`), `SeriesService`, expansión de ocurrencias, editar/cancelar `one`/`all`, **truncación del maestro** (§11.2) | serie 14/21/28 ago creada en MGCI y en Google; **medir cuántos correos manda al cancelar y al truncar** | sí |
| **F5** · Ciclo de vida | §11.1 (extender serie al mover el vencimiento) y §11.2 (cancelar/truncar al completar tarea o cerrar ticket, defaults por estado destino, `bulk` que no cancela) | completar la tarea el 20 ago y ver la oferta de truncar 21 y 28; cerrar 20 tickets en lote y ver que solo reporta | sí |
| **F6** · Fuera de plazo | §11.4: señalización en Reuniones / Tareas / Ticket + acciones ofrecidas; nunca escribir vencimientos solo | mover una cita al 3 sep con tarea que vence el 31 ago y ver las 3 señales | sí |
| **F7** · Push | §12: `watch_events`/`stop_channel`/incremental, controller público, `CalendarPushJob`, `RenewCalendarChannelsJob` + `schedule.yml`, columnas de canal, descarte de eventos ajenos (§12.4) | mover la cita en Google y verla cambiar **sin abrir el ticket** | sí |
| **F8** | *Diferido*: recordatorios internos, bandeja de reuniones a nivel cuenta, `scope: 'following'` | — | — |

**Dependencias que conviene tener presentes:**

- **F3 requiere** una cuenta con el flag `google_calendar` y al menos un agente con
  Calendar conectado. Sin eso solo se puede probar el camino `local_only`.
- **F4 depende de F3**: la truncación y el `one`/`all` se apoyan en el maestro.
- **F5 depende de F4** (usa la truncación) y toca `case_tickets#transition` y
  `#bulk`, que son código vivo del módulo — es la fase de mayor riesgo de regresión.
- **F7 tiene una dependencia externa**: verificar el dominio en Google Cloud
  (§12.2). Conviene arrancar ese trámite en paralelo desde F3, no al llegar a F7.
- **F7 es aditiva**: si nunca se hace, el módulo funciona igual — solo que la
  actualización llega al abrir el ticket en vez de al instante.

**Corte natural para una primera entrega:** F0–F4. Ahí ya se agendan reuniones y
series con el cliente invitado y Meet. F5 y F6 son las que evitan los daños
silenciosos, así que no deberían quedarse fuera mucho tiempo.

Las migraciones se generan **al final** de cada fase que las requiera, con
timestamp posterior a todo lo existente en `db/migrate`.

---

## 8. Trampas específicas de esta entrega

1. **`conferenceDataVersion: 1`** o no hay Meet, y falla en silencio (§4.1).
2. **Cancelar una ocurrencia NO es `DELETE`** sobre la instancia: es `PATCH` con
   `status: 'cancelled'`. Un `DELETE` sobre el id de instancia puede tumbar
   comportamiento inesperado en la serie.
3. **`list_events` usa `singleEvents: true`** → ya expande instancias y **nunca
   devuelve el maestro**. Quien busque el evento recurrente por ahí no lo va a
   encontrar; para eso está `list_instances` sobre el id del maestro.
3b. **Nunca reconciliar una ocurrencia de serie por su id de instancia** (§5.1):
   si alguien movió la serie completa desde Google, esos ids ya no existen y el
   404 haría que MGCI cancelara reuniones que están vivas. Siempre vía el maestro.
4. **`sendUpdates: 'all'` ya está activo** en `create_event`/`update_event`: en el
   momento en que se agrega el email del contacto a `attendees`, **el cliente
   recibe correo**. Ver §10.2 — `sendUpdates` se decide por el *diff*, no por un
   ajuste, y cancelar una serie se hace **sobre el maestro** (un solo aviso).
5. **`UNTIL` del RRULE va en UTC** con formato `20261012T235959Z`. Mezclarlo con
   hora local corre la última ocurrencia un día.
6. **Zona horaria**: `starts_at` se guarda UTC; la hora que el agente ve en su
   Google es la de `account_timezone` (ya resuelto por el servicio). Anclar ahí y
   guardar el tz en la fila para no re-interpretar históricos.
7. **El evento vive en el calendario del organizador.** Reasignar el ticket **no**
   mueve el evento; si ese agente desconecta su OAuth, la serie queda huérfana en
   su Google. Por eso `organizer_id` se persiste y se muestra en la fila.
8. **Enums al final.** `case_events` 30-33 se agregan al final; no reordenar.
   No se agrega feature nueva a `config/features.yml` (se reutilizan
   `case_management` y `google_calendar`) — así se evita por completo el riesgo
   del bitfield FlagShihTzu.
9. **Prettier**: no correr `eslint --fix` sobre `TicketDetail.vue` / `TicketTasks.vue`.
   Verificar "0 errores NUEVOS" contra HEAD, no apuntar a cero.
10. **Toasts**: `this.$emitter.emit('newToastMessage', …)`, nunca `bus.$emit`.
11. **Raíz de `TicketMeetings.vue`**: `flex flex-col flex-1 w-full h-full overflow-hidden`.
12. **Nada de "osTicket"** en cadenas visibles.

---

## 9. Riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Deriva MGCI ↔ Google (edición desde Google) | medio | push en tiempo real (§12) **+** reconciliación perezosa como red de seguridad (§5, §12.5) |
| Push recibe pings de eventos personales del agente | medio | `events.watch` es por calendario: descartar en memoria todo id ajeno, sin persistir ni loguear (§12.4) |
| Canal de push caducado o ping perdido → deriva silenciosa | medio | renovación diaria + la reconciliación perezosa nunca se retira (§12.5) |
| Correo no deseado al cliente | **alto** | `sendUpdates` derivado del diff + cancelación sobre el maestro (§10.2) |
| Evento huérfano si el organizador se desconecta | medio | co-invitados siempre presentes + acción "hacerme organizador" (§10.3) |
| Cuota de la API de Google | bajo | espejo en job con reintentos acotados; tope de 100 ocurrencias; reconciliación con throttle |
| Agente sin Calendar conectado | bajo | `local_only` es un estado de primera clase, no un error |
| Series largas inflando `case_meetings` | bajo | prohibidas las series infinitas; tope duro de 100 |
| Reuniones huérfanas tras completar la tarea / cerrar el ticket | **alto** | ofrecer cancelarlas en el mismo diálogo, con default según el estado destino (§11.2) |
| Cancelar la reunión de validación al marcar `resolved` | medio | `resolved`/`validating` ofrecen la casilla **desmarcada**: no son estados terminales (§11.2) |
| Cierre en lote disparando correos a N clientes | **alto** | `bulk` no cancela reuniones; solo reporta cuáles quedaron con citas vivas (§11.2) |
| `UNTIL` mal convertido borra la última ocurrencia en silencio | medio | preferir `COUNT`; test de serie vespertina en F3 (§11.5) |
| Reagendado externo empuja la reunión más allá del vencimiento / SLA | medio | señalar en 3 lugares; ofrecer la acción, nunca escribir el vencimiento solo (§11.4) |

---

## 10. Principio rector: cero configuración nueva

**Ninguna** de estas soluciones agrega una pantalla de ajustes, un feature flag
ni una casilla por cuenta. Todas derivan su comportamiento de datos que el ticket
**ya tiene**. Es la restricción que ordena las tres decisiones siguientes.

### 10.1 Deriva con Google → reconciliar al leer

Resuelto en §5: se relee desde Google al abrir la pestaña, con el token que el
organizador ya concedió. Sin webhooks, sin cron, sin endpoint público, sin
configuración. Google gana en fecha/hora/cancelación; MGCI nunca sobrescribe
hacia allá durante la reconciliación.

### 10.2 Correo al cliente → que la regla salga del diff, no de un ajuste

Tres reglas automáticas, ninguna configurable:

**a) A quién se invita se deriva del ticket.**

```
  ticket tiene contacto CON email  →  "Invitar al cliente" viene marcado
  ticket sin contacto (interno)    →  casilla deshabilitada, con la razón visible
  contacto sin email               →  casilla deshabilitada, con la razón visible
```

No hay ajuste de "invitar por default": lo dicta el dato. El agente puede
desmarcarlo en el momento, y eso queda guardado en `notify_client` de esa
reunión — no como preferencia global.

**b) `sendUpdates` se decide comparando qué cambió, no por configuración.**

Google reenvía la invitación en **cualquier** `PATCH` si mandas
`sendUpdates: 'all'`. Corregir un typo en el título no debe volver a escribir al
cliente. Entonces:

```
  cambió fecha / hora / lista de invitados / cancelación  →  sendUpdates: 'all'
  cambió solo título / descripción / notas internas       →  sendUpdates: 'none'
```

Es una función pura del diff del registro. Cero decisiones para el usuario.

**c) Cancelar una serie se hace SOBRE EL MAESTRO, nunca instancia por instancia.**

> Matiz importante si la serie **ya empezó**: borrar el maestro elimina también las
> ocurrencias pasadas. En ese caso se **trunca** el RRULE en vez de borrarlo — ver
> §11.2, "Serie a medio camino".

Aquí conviene corregir lo que dije antes sobre "N correos de cancelación": eso
solo ocurre si se cancela ocurrencia por ocurrencia. Si se opera sobre el evento
recurrente maestro, Google emite **un** aviso de cancelación por la serie
completa. Por eso `scope: 'all'` debe ir siempre contra el maestro.

```
  scope: 'all'  →  DELETE maestro          →  1 aviso al cliente     ✔
  scope: 'one'  →  PATCH instancia         →  1 aviso de esa fecha   ✔
  bucle sobre las N ocurrencias            →  N avisos               ✘ prohibido
```

> ⚠️ El "un solo aviso" es comportamiento del sistema de Google, no nuestro:
> **verificarlo empíricamente en F2** con una serie de prueba antes de darlo por
> bueno. Si resultara que manda uno por ocurrencia, la alternativa sin
> configuración es cancelar el maestro con `sendUpdates: 'none'` y avisar al
> cliente por el canal del ticket, que ya existe.

El modal sigue diciendo **exactamente** lo que va a pasar antes de confirmar
("se enviará 1 aviso de cancelación a cliente@empresa.com"). Eso es texto, no
configuración.

### 10.3 Organizador → co-invitados automáticos, y reasignar no mueve el evento

El evento vive en el calendario del organizador. Mover la propiedad a otro agente
exigiría el OAuth del otro y volvería a escribirle al cliente. Así que **no se
mueve**. En cambio:

```
  al crear la reunión, van SIEMPRE como invitados:
     · el organizador (dueño del calendario)
     · el agente asignado al ticket   ← aunque NO tenga Google conectado
     · el cliente, si aplica (§10.2a)

  al reasignar el ticket:
     · se agrega el nuevo asignado como invitado del evento existente
       (con el token del organizador, sendUpdates: 'none' para el cliente)
```

La pieza que lo hace gratis: **un invitado es solo un correo**. Un agente sin
integración de Google igual recibe la invitación en su bandeja y la cita le cae
en su calendario, sea cual sea. No hace falta que nadie conecte nada.

Y si el organizador desconecta su OAuth, la reconciliación de §5 lo detecta al
primer intento fallido: la fila se marca y ofrece la acción **"hacerme
organizador"**, que recrea el evento bajo el agente actual y lo re-liga. Es un
botón contextual en la fila, no una pantalla de ajustes.

---

## 11. Ciclo de vida: la tarea y su serie son independientes

Caso de referencia que motivó esta sección:

```
  tarea T007   inicia mar 11 ago 2026     vence lun 31 ago 2026
  serie  S01   vie 14 · vie 21 · vie 28 ago, 16:00
               RRULE:FREQ=WEEKLY;BYDAY=FR;COUNT=3   (DTSTART = 14 ago 16:00)

  ── ago 2026 ──────────────────────────────────────────────
   L   M   X   J   V   S   D
  10 (11) 12  13 (14) 15  16      11 = inicia tarea
  17  18  19  20 (21) 22  23      14/21/28 = reuniones 16:00
  24  25  26  27 (28) 29  30
 (31)                             31 = vence tarea
```

El sistema trata `case_task` y `case_meeting_series` como entidades separadas. El
usuario las percibe como una sola cosa ("las reuniones de esa tarea"). Esa brecha
produce dos incidentes concretos, y **ninguno se resuelve con un ajuste**: se
resuelven ofreciendo la acción correcta en el momento exacto.

### 11.1 Mover el vencimiento de la tarea no mueve la serie

Si `T007` pasa a vencer el 15 de septiembre, las reuniones siguen siendo 14, 21 y
28 de agosto. No se extienden solas — **y no deben hacerlo en silencio**, porque
cada ocurrencia nueva le escribe al cliente.

**Comportamiento:** al guardar un cambio de `due_at` en una tarea que tiene serie
con ocurrencias futuras, el propio diálogo de la tarea ofrece —sin bloquear—
*"extender las reuniones hasta la nueva fecha"*. Si se acepta, se recalcula el
`COUNT`/`UNTIL` y se agregan ocurrencias; si no, no pasa nada. Es una casilla
contextual en un diálogo que ya se está mostrando, no una preferencia.

### 11.2 Completar la tarea (o cerrar el ticket) deja reuniones huérfanas

El caso caro: la tarea se termina el 20 de agosto y las reuniones del 21 y 28
**siguen en pie, con el cliente ya invitado**. Se presenta a una reunión de algo
ya resuelto.

```
  marcar tarea done ──► ¿tiene reuniones futuras (scheduled)?
  transición de estado      │ no → seguir normal
  del ticket                ▼ sí
                    "Esta tarea tiene 2 reuniones futuras.
                     [x] Cancelarlas y avisar al cliente"
                            │
                            └─► si son TODAS las de la serie → cancelar el
                                MAESTRO (§10.2c) → 1 solo aviso
```

#### No todos los "fines" son iguales

Éste es el punto fino, y equivocarlo cancela reuniones que hacían falta. El enum
de estados permite volver atrás desde `resolved`:

```
  in_progress ──► resolved ──► validating ──► closed ──┐
                     │  ▲          │            │      │ reabrir
                     ▼  └──────────┘            ▼      ▼
                 in_progress               in_progress ◄┘

  cancelled  ← dead end, no sale a ningún lado
```

Por eso el default de la casilla **depende del estado destino**:

| Transición | ¿Se ofrece? | Casilla por defecto | Razón |
|---|---|---|---|
| `resolved` | sí | **desmarcada** | No es terminal. La reunión futura puede ser *justo* la de validación con el cliente |
| `validating` | sí | **desmarcada** | Se está validando con el cliente: cancelarle la cita es lo contrario de lo que se busca |
| `closed` | sí | **marcada** | Terminal. Reabrir existe, pero es excepcional |
| `cancelled` | sí | **marcada** | Dead end: no hay vuelta posible |
| tarea `done` | sí | **marcada** | El trabajo de esa tarea terminó |

En todos los casos el agente decide con la lista de reuniones delante. Nunca se
cancela sin mostrarlas.

#### Cancelar no es reversible — decirlo

Un ticket `closed` puede reabrirse a `in_progress`, pero **las reuniones canceladas
no vuelven**: en Google la cancelación es destructiva y el cliente ya recibió el
aviso. El texto del diálogo debe decirlo en una línea, no dejarlo implícito.

#### Alcance: qué reuniones entran

- Al **completar una tarea**: las futuras **de esa tarea**. Las de otras tareas y
  las que cuelgan del ticket sin tarea (`case_task_id` NULL) no se tocan.
- Al **cerrar el ticket**: las futuras del ticket completo — las de todas sus
  tareas **más** las del ticket sin tarea.
- Solo `scheduled`. Las ya `held`, `no_show` o `cancelled` se ignoran.
- Solo futuras respecto de `Time.current`.
- Volver una tarea de `done` a `pending` **no resucita** las reuniones canceladas.

#### Serie a medio camino: TRUNCAR, no cancelar

El caso real: la tarea se completa el **20 de agosto**; la reunión del 14 **ya se
realizó** y quedan vivas la del 21 y la del 28.

Aquí la regla de §10.2c ("si son todas las de la serie → cancelar el maestro") **no
aplica**, y aplicarla haría daño: borrar el maestro en Google **elimina también las
instancias pasadas**, así que se perdería el registro de la reunión que sí ocurrió.
La alternativa ingenua —cancelar el 21 y el 28 una por una— manda **dos** correos.

La salida correcta es truncar la recurrencia:

```
  PATCH maestro  →  RRULE:FREQ=WEEKLY;BYDAY=FR;UNTIL=<justo después del 14 ago>

  resultado:  14 ago  ✔ conservada (histórico intacto)
              21 ago  ✘ desaparece
              28 ago  ✘ desaparece
              → UN solo aviso al cliente, no dos
```

Regla completa, según el estado de la serie:

| Situación | Técnica | Correos |
|---|---|---|
| Ninguna ocurrencia realizada aún | `DELETE` del maestro | 1 |
| Serie ya empezada (hay realizadas) | **`PATCH` del maestro truncando el `UNTIL`** | 1 |
| Reuniones sueltas, sin serie | `PATCH` instancia `status: cancelled` | 1 por cita |

⚠️ El `UNTIL` de la truncación cae en la misma trampa de §11.5: va en **UTC**, y
debe quedar **después** de la última ocurrencia conservada. Calcularlo sobre la
fecha local se come esa última reunión del historial.

#### El cierre en lote NO cancela reuniones

`case_tickets#bulk` cierra tickets en masa desde la cola. Ahí no hay diálogo
posible, y aplicar el default marcado dispararía **correos de cancelación a N
clientes distintos de una sola vez, sin que nadie los vea**. Es exactamente el
daño silencioso que este plan evita en todas partes.

```
  bulk close de 20 tickets
        │
        ├─► cierra los 20 normalmente
        │
        └─► NO toca ninguna reunión. Responde:
            "3 de los tickets cerrados tienen reuniones futuras" + enlace
            para revisarlos uno por uno
```

Cancelar en masa queda como acción explícita y separada, si algún día se pide.
Nunca como efecto secundario de cerrar tickets.

### 11.3 Reglas de forma del formulario (derivadas del caso)

- **`DTSTART` = la primera reunión** (14 ago), no el inicio de la tarea (11 ago).
- **Duración por defecto: 1 hora.** Google exige hora de fin; "a las 16:00" no la
  da. Sin default, la creación falla.
- **Preferir "después de N reuniones" (`COUNT`) sobre "termina el DD/MM"
  (`UNTIL`)** cuando el usuario enumera fechas. `COUNT=3` es literal, no depende
  de zona horaria y esquiva por completo la trampa de §8.5. `UNTIL` queda para
  cuando el usuario piensa en un plazo, no en un número de sesiones.
- **Si las fechas no son un patrón regular** (p. ej. 14, 20 y 29), no hay serie
  posible: la UI debe ofrecer crear reuniones sueltas, o crear la serie y mover
  una ocurrencia (`scope: 'one'`). No intentar "adivinar" un RRULE aproximado.
- **Festivos**: el RRULE no los conoce. Se resuelve moviendo la ocurrencia
  afectada, no complicando la regla.

### 11.4 Una reunión se va MÁS ALLÁ del vencimiento (desde Google)

Caso: alguien arrastra la reunión del 21 de agosto al **3 de septiembre**, cuando
la tarea `T007` vence el **31 de agosto**. La reconciliación (§5.1) trae la fecha
nueva. ¿Qué le pasa a la tarea?

Hay **tres** vencimientos distintos en juego y confundirlos es el error caro:

| Campo | Naturaleza | ¿Lo puede mover un arrastre en Google? |
|---|---|---|
| `case_tasks.due_at` | organización interna del trabajo | solo si un humano lo acepta |
| `case_tickets.due_at` / `effective_due_at` | compromiso con el cliente | **no** |
| `sla_status`, `resolution_time_target` | métrica de servicio | **nunca** |

**Regla dura: la reconciliación no mueve ningún vencimiento.** Escribir `due_at`
automáticamente sería una escritura a ciegas sobre un campo de negocio, disparada
por alguien moviendo una cita en *su* calendario personal, y sin ningún humano
presente al que preguntarle. Y si el corrimiento cruza el `effective_due_at`, se
estaría reescribiendo el SLA desde fuera del sistema. **No.**

Lo que sí se hace, en tres niveles de costo creciente:

```
  1. REGISTRAR   meeting_updated con payload beyond_task_due: true
                 (gratis — el evento ya se emite en §5.2)

  2. SEÑALAR     la misma comparación de fechas, en los 3 lugares donde se mira:

     Reuniones   R002 · 3 sep 16:00   ⚠ posterior al vencimiento de la tarea
     Tareas      T007 · vence 31 ago  ⚠ tiene una reunión fuera de plazo
     Ticket      ⚠ SOLO si además cruza effective_due_at → señal de SLA

     (TicketTasks.vue ya marca tareas vencidas, línea ~547: es un marcador hermano)

  3. OFRECER     acciones en la fila, cuando aparece un humano — nunca antes:

     · "Mover el vencimiento de la tarea al 4 sep"  → escribe case_tasks.due_at
                                                      + case_event due_date_changed (28, YA EXISTE)
     · "Regresar la reunión al plazo"               → sí escribe hacia Google;
                                                      es acción humana explícita,
                                                      no reconciliación

     Si cruzó el SLA del ticket: NO se ofrece mover nada. Solo se señala.
     Esa decisión tiene peso de política → el camino es `escalate`, que ya existe.
```

Cruce con §11.2: si la tarea ya estaba **completada** y la reunión se fue al 3 de
septiembre, es el caso del huérfano — reunión viva de algo ya cerrado. La oferta
correcta ahí es cancelarla, no mover fechas.

### 11.5 Ejemplo trabajado del `UNTIL` (por qué se prefiere `COUNT`)

Cuenta en `America/Mexico_City` (UTC−6, sin horario de verano desde 2022):

```
  intención: "que termine el 31 de agosto"
  ingenuo:   UNTIL=20260831T235959Z   ← fecha local con una Z pegada
  correcto:  UNTIL=20260901T055959Z   ← 31 ago 23:59:59 CST en UTC

  reuniones a las 16:00 (= 22:00 UTC)  → ambos valores funcionan. El bug no se ve.
  reuniones a las 18:00 (= 00:00 UTC del día siguiente)
                                       → el ingenuo BORRA la última ocurrencia,
                                         en silencio y sin error.
```

Este es el modo de falla más traicionero de toda la entrega: no lanza excepción,
no deja `sync_error`, simplemente faltan reuniones. Test obligatorio en F3 con
una serie de horario vespertino.

---

## 12. Push en tiempo real (webhooks de Google) — F6

Decisión del usuario: **adelante con webhooks.** Lo que sigue corrige a la baja mi
estimación inicial de costo: medido contra el repo, casi todo lo que hacía falta
**ya existe**.

### 12.1 Lo que ya está y no hay que construir

| Requisito de `events.watch` | Estado en el repo |
|---|---|
| Endpoint público, sin auth, alcanzable por Google | **YA**: `config/routes.rb:770` monta `google_calendar/callback` fuera del namespace de API, en `ApplicationController`. El receptor es la misma línea |
| HTTPS con certificado válido | **YA** (develop.wintook.com) |
| Cron para renovar canales | **YA**: `config/schedule.yml` + sidekiq-cron, cola `scheduled_jobs`, con jobs cada 1 y 5 min |
| Almacén de estado efímero | **YA**: `Redis::Alfred`, usado por el propio callback de OAuth |
| OAuth con refresh | **YA**: `UserCalendarIntegration` + `GoogleCalendarService#refresh_token_if_needed` |

### 12.2 Lo único que sí es nuevo fuera del código

**Verificar el dominio** en Google Search Console y registrarlo como dominio de
notificaciones en el proyecto de Google Cloud. Es requisito duro de Google: no
acepta una URL de push en un dominio no verificado.

> Es un paso **único, de despliegue, hecho por un admin**. No es una pantalla de
> ajustes, no es por cuenta ni por agente. La restricción de "cero configuración
> nueva" (§10) se mantiene intacta: ningún usuario final configura nada.

### 12.3 Cómo funciona

Punto que define todo el diseño: **el ping de Google no dice qué cambió.** Llega
vacío, con encabezados. Hay que preguntar después, con `syncToken`.

```
  agente mueve la cita en su Google Calendar
        │
        ▼
  POST /google_calendar/notifications        ← headers, cuerpo VACÍO
        X-Goog-Channel-ID     nuestro id de canal
        X-Goog-Channel-Token  secreto nuestro  ← autentica el ping
        X-Goog-Resource-State sync | exists
        │
        ├─ token no coincide → 404 y fuera (no revelar nada)
        ├─ state = sync      → 200, es el saludo inicial, no hacer nada
        │
        ▼  responder 200 YA (Google reintenta si tardas) y encolar:
  CalendarPushJob
        │
        ├─► events.list(syncToken guardado)   ← incremental: solo lo que cambió
        │        └─ 410 GONE → token caducado: full resync de la ventana futura
        │
        ├─► por cada evento devuelto:
        │        ¿su id está en nuestras case_meetings / series?
        │           no → DESCARTAR sin guardar ni registrar   ← §12.4
        │           sí → aplicar la MISMA lógica de §5.1/§5.2
        │
        └─► guardar el nuevo syncToken
```

La pieza clave de economía: **la lógica de aplicar el cambio es exactamente la de
§5.1 y §5.2**. El webhook no reimplementa nada, solo cambia *quién dispara* la
reconciliación: antes era "alguien abrió la pestaña", ahora es "Google avisó".
`ReconcileService` se reutiliza tal cual.

### 12.4 Privacidad — el punto que hay que mirar de frente

`events.watch` es **por calendario, no por evento**. No existe forma de vigilar
solo nuestras reuniones. Consecuencia: MGCI recibirá pings por **cualquier**
cambio en el calendario primario del agente, incluidos sus eventos personales.

Mitigación, que debe ser explícita en el código y no un descuido:

- El ping en sí **no trae datos** (solo dice "algo cambió").
- Al hacer el `events.list` incremental, todo evento cuyo id **no** esté en
  `case_meetings` / `case_meeting_series` se **descarta en memoria**: no se
  persiste, no se registra en `case_events`, **no se escribe en logs**.
- Nunca se loguea el cuerpo de la respuesta de `events.list`.
- Al desconectar la integración, se llama `channels.stop` y se borra el canal.

Esto conviene decirlo en la pantalla de conexión de Google Calendar, en una línea:
que MGCI solo lee y conserva las reuniones creadas desde el sistema.

### 12.5 El webhook NO reemplaza la reconciliación perezosa

Regla de diseño, no opcional: **se quedan las dos.**

```
  push (§12)          rápido, best-effort          ── puede fallar
  reconciliar al leer red de seguridad, garantizada ── siempre correcta
```

Los canales caducan, Google descarta notificaciones, el servidor puede estar
caído durante el ping, el `syncToken` puede invalidarse. Un sistema que solo
confía en push acumula deriva silenciosa. La reconciliación al abrir la pestaña
cuesta ~0 llamadas cuando no hay nada que revisar (§5), así que mantenerla es
gratis y convierte el push en una mejora de latencia, no en un punto único de fallo.

### 12.6 Columnas y piezas nuevas

En `user_calendar_integrations` (tabla que **ya comparte** el módulo de
seguimientos — solo se agregan columnas, no se toca lo existente):

| Columna | Uso |
|---|---|
| `push_channel_id` | uuid del canal que registramos |
| `push_resource_id` | id del recurso que devuelve Google (necesario para `channels.stop`) |
| `push_channel_token` | secreto para autenticar el ping |
| `push_expires_at` | caducidad que informa Google → la usa el renovador |
| `sync_token` | cursor incremental de `events.list` |

Piezas:

- `GoogleCalendarService#watch_events` / `#stop_channel` / `#list_events_incremental(sync_token:)`
- `GoogleCalendarNotificationsController` (público, `POST`, responde 200 rápido)
- `Cases::CalendarPushJob` (procesa fuera del request)
- `Cases::RenewCalendarChannelsJob` + entrada en `config/schedule.yml`
  (diario; renueva lo que caduque en < 48 h)
- Alta del canal: al conectar la integración y, de forma perezosa, la primera vez
  que una cuenta agenda una reunión (así no se abren canales para agentes que
  nunca usan el módulo)

### 12.7 Trampas propias del push

1. **Responder 200 antes de trabajar.** Google reintenta con backoff si tardas;
   procesar dentro del request genera notificaciones duplicadas.
2. **`X-Goog-Resource-State: sync`** es el saludo al crear el canal, no un cambio.
   Ignorarlo o se dispara un resync inútil por cada canal.
3. **Autenticar con `X-Goog-Channel-Token`.** El endpoint es público: sin ese
   secreto, cualquiera puede provocar sincronizaciones. Ante token inválido, 404.
4. **Idempotencia.** El mismo cambio puede llegar dos veces; aplicar por estado
   final (la fecha que dice Google), nunca por incrementos.
5. **`syncToken` inválido → 410 GONE**: no es un error fatal, es "haz resync
   completo". Manejarlo o el canal queda muerto en silencio.
6. **`channels.stop` al desconectar.** Si no, Google sigue enviando pings a un
   endpoint que ya no tiene tokens para responderlos.
7. **Un canal por integración, no por reunión.** Registrar uno por cita agota la
   cuota de inmediato.
