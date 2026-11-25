# Ver el calendario de los compañeros (respetando lo que cada uno comparte en Google)

> Rama: `fix/calendario_google` (desde `origin/develop` 92fb814b) · Plan v1.3 · 25/11/2026 · F0 completa
> Estado: **solo plan** — no se programa nada hasta el OK.

---

## 1. Qué se pide

Entre los agentes de una misma cuenta, poder **revisar la agenda de un compañero** desde la
pantalla del calendario, **siempre y cuando ese compañero lo permita** en la configuración de
su Google Calendar («Compartir con personas específicas»).

Y además (v1.1): **agendarle a un compañero sin que el evento quede en el calendario de quien
lo crea**, también solo si el compañero lo permite (permiso «Hacer cambios en los eventos»).

Y (v1.2): que cada agente pueda **dar esos permisos desde el propio sistema** («Compartir mi
calendario»), sin tener que ir a calendar.google.com.

---

## 2. Cómo está hoy

```
  Pantalla Calendario (agente A)
  ┌──────────────────────────────────────────┬──────────────────────┐
  │  FullCalendar                            │  Panel lateral       │
  │  · eventos de A (detalles)               │  ▸ Próximos          │
  │  · franjas de color de fondo =           │  ▸ Calendarios       │
  │    «ocupado» de TODOS los compañeros     │  ▾ Disponibilidad    │
  │    (sin título, sin saber de quién)      │     ● Beto  ocupado  │
  │                                          │     ● Caro  libre    │
  │                                          │     ○ Dani  sin con. │
  └──────────────────────────────────────────┴──────────────────────┘
```

Lo que pasa por detrás:

```
  A abre el calendario
        │
        ▼
  GET /google_calendar/availability
        │   availability_controller.rb
        ▼
  por cada compañero B conectado:
     GoogleCalendarService.new(integración DE B)   ◄── usa el token de B
        │
        ▼
  Google: freeBusy(primary de B)  ──►  siempre responde (B es el dueño)
```

**El hueco:** el sistema lee el calendario de B **con la llave de B**, así que Google nunca
pregunta «¿B le compartió esto a A?». Hoy se ve el ocupado de todos aunque nadie haya
compartido nada, y no hay forma de ver detalles aunque B sí los haya compartido.

Además existe `GET /google_calendar/events/agent_events?agent_id=` (events_controller.rb:47)
con la misma lógica (token de B); **ninguna pantalla lo usa**.

---

## 3. La idea

Consultar el calendario de B **con la llave de A** y usando el **correo de Google de B** como
identificador del calendario. Google aplica solo lo que B configuró:

```
  A abre el calendario
        │
        ▼
  GET /google_calendar/coworkers/events?agent_ids[]=B
        │
        ▼
  GoogleCalendarService.new(integración DE A)       ◄── usa el token de A
        │
        ▼
  Google: calendario «b@correo.com»
        │
        ├─ B compartió «Ver todos los detalles»  ──► eventos con título y hora
        ├─ B compartió «Ver solo libre/ocupado»  ──► solo bloques ocupados
        └─ B no compartió con A                  ──► sin acceso
```

Lo que A ve por compañero:

```
  Configuración de B en Google        Estado en el panel     En el calendario
  ─────────────────────────────────   ────────────────────   ─────────────────────────
  «Ver todos los detalles»            Detalles               eventos de B con título
  «Hacer cambios…» / «Administrar»    Puede agendarle        igual + aparece en «Agendar a» (F3b)
  «Ver solo libre/ocupado»            Solo ocupado           bloques «Ocupado»
  No compartido con A                 No compartido          nada
  B no conectó Google en el sistema   Sin conectar           nada
  A no conectó Google                 (aviso: «Conecta tu Google para ver a tus compañeros»)
```

Detalles que Google resuelve solo:
- Los eventos que B marcó como **privados** llegan como «Ocupado» aunque haya compartido detalles.
- **No hace falta reconectar:** el permiso que ya pedimos (`auth/calendar`, completo) alcanza
  para leer calendarios que otros te compartieron.

---

## 4. Pantalla propuesta

```
  ┌──────────────────────────────────────────┬────────────────────────────┐
  │  Lun 24   Mar 25   Mié 26                │  ▾ Compañeros              │
  │ ┌───────┐                                │   ☑ ● Beto    Detalles     │
  │ │Junta  │ ← mío (color de mi calendario) │   ☑ ● Caro    Solo ocupado │
  │ └───────┘                                │   ☐ ● Dani    No compartido│
  │ ┌───────────┐                            │   ☐ ○ Eli     Sin conectar │
  │ │Beto·Visita│ ← de Beto (su color, borde │                            │
  │ │ cliente X │   punteado, no se arrastra)│  «No compartido»: pídele   │
  │ └───────────┘                            │  que comparta su calendario│
  │ ░░░░░░░░░░░░ ← Caro: «Ocupado»           │  con tu correo a@...       │
  └──────────────────────────────────────────┴────────────────────────────┘
```

- La sección «Disponibilidad» pasa a llamarse **«Compañeros»** y cada uno lleva una casilla.
- Lo palomeado se recuerda por agente (localStorage, conveniencia; si falla, nada palomeado).
- Clic en un evento de compañero → ventanita **solo lectura** (título, hora, de quién). Sin
  editar, sin arrastrar, sin borrar.
- Solo componentes nativos del sistema (checkbox, avatar, tooltip existentes).

---

## 5. Qué NO se toca

```
  ┌───────────────────────────────────────────────────────────────┐
  │  El bot de IA que agenda citas sigue usando el token del      │
  │  dueño del calendario (lo conectó para eso):                  │
  │   · contact_trackings/availability_slot_service.rb            │
  │   · agenda_items/busy.rb                                      │
  │   · cases/meetings/* (Tareas agendadas)                       │
  │  Este arreglo es SOLO lo que un agente ve de otro en pantalla.│
  └───────────────────────────────────────────────────────────────┘
```

- «Compartir agenda» (`sharing_controller.rb`, mandar mi agenda a un contacto) no cambia.
- **Nunca** se crea ni se lee nada del compañero con SU propia conexión desde la pantalla:
  eso funcionaría aunque no haya dado permiso, que es justo lo que se quiere evitar.
- No se cambia el permiso OAuth ni se pide reconectar.

---

## 6. Fases

### F0 — Medir a Google (sin código del producto)
Con **dos cuentas de Google reales** (A y B) conectadas en dev, probar desde la consola de
Rails con el token de A, contra `b@…`, los tres casos de compartir de B:

| Caso de B            | `events.list(calendarId=b@)`         | `freeBusy(items=[b@])`        |
|----------------------|--------------------------------------|-------------------------------|
| Detalles             | ¿200 + `accessRole=reader`?          | ¿busy[]?                      |
| Solo libre/ocupado   | ¿200 sin títulos o 403/404?          | ¿busy[]?                      |
| Hacer cambios        | ¿200 + `accessRole=writer`?          | ¿busy[]?                      |
| No compartido        | ¿404 notFound?                       | ¿`errors: notFound`?          |

Caso extra (escritura, con OK): con «Hacer cambios», A crea un evento de prueba en `b@`
→ confirmar que aparece en el calendario de B, **no** en el de A, y luego borrarlo.

Se anota lo que responde de verdad; F1 se ajusta a eso.

#### F0 — resultados (25/11/2026, cuenta 2 de dev, solo lectura)

Cuentas conectadas en la cuenta 2:

| Agente                    | Correo de Google              | Estado del permiso            |
|---------------------------|-------------------------------|-------------------------------|
| #1 Admin                  | aliverio.mx@gmail.com         | sirve                         |
| #4 Andres Liverio MX      | aliverio.mx@gmail.com         | (mismo Google que #1)         |
| #24422 Jose Luis Herrera  | camion01kontrolya@gmail.com   | **vencido** (`invalid_grant`) |

Medido (script de solo lectura, sin imprimir títulos):

| A mira a B                         | `events.list(b@)` | `freeBusy(b@)`                 | `calendarList(b@)` |
|------------------------------------|-------------------|--------------------------------|--------------------|
| aliverio → camion01 (no compartido)| **404 notFound**  | 200, `errors: ["notFound"]`    | 404                |
| camion01 → aliverio                | no se pudo: token de camion01 vencido                              |||

Conclusiones hasta ahora:
- «No compartido» se detecta con certeza: 404 en `events.list` **y** `notFound` en `freeBusy`.
  Ojo: `freeBusy` responde **200** aunque no haya acceso; hay que leer `errors`, no el código.
- Dos casos nuevos que el plan no tenía:
  1. **Mismo Google en dos agentes** (#1 y #4): mirar al «compañero» es mirar tu propio
     calendario → se trata como detalles completos (sin preguntar a Google).
  2. **Permiso vencido del que mira o del compañero** → estado «Reconectar» (hoy el panel de
     disponibilidad lo traga en silencio y lo muestra como «Sin conectar», sin decir que
     basta con reconectar).
- ~~Pendiente medir los demás niveles~~ → hecho abajo (F0 completa). Nota original: requería que
  camion01 comparta su calendario con aliverio en Google (ver pasos en el chat).

#### F0 — resultados completos (25/11/2026, vía ACL desde el sistema)

Pareja: dueño **#4 Andres** (aliverio.col@gmail.com), quien mira **#1 Admin**
(aliverio.mx@gmail.com). Los permisos se dieron **desde el sistema** con la conexión de Andres
(ACL `insert/patch` con `sendNotifications=false`) — es decir, F3c ya probada contra Google.
Al terminar: eventos de prueba borrados (204), regla quitada (204), ACL igual que al inicio
(`user:owner` solamente).

| Nivel (ACL role)             | `events.list(b@)`                  | Campos que llegan                                     | `freeBusy` |
|------------------------------|------------------------------------|-------------------------------------------------------|------------|
| Sin compartir                | **404 notFound**                   | —                                                     | 200 + `errors: notFound` |
| Ver detalles (`reader`)      | 200, `accessRole=reader`           | título, descripción, lugar, organizador               | ok |
|   · evento **privado**       |                                    | solo `start/end`, `visibility=private`, **sin título**| |
| Solo ocupado (`freeBusyReader`)| 200, `accessRole=freeBusyReader` | **todos** sin título: solo `start/end`, `visibility=private` | ok |
| Hacer cambios (`writer`)     | 200, `accessRole=writer`           | como `reader`                                         | ok |

Escritura:

| Prueba                                   | Resultado |
|------------------------------------------|-----------|
| Admin crea en `aliverio.col@` con `writer` | 200 · organizer = **Andres**, creator = **Admin**, sin invitados |
|   ¿aparece en el calendario de Andres?    | **sí** |
|   ¿aparece en el calendario de Admin?     | **no** ✔ (justo lo que pide F3b) |
| Admin crea con `reader`                   | **403 requiredAccessLevel** ✔ |

`calendarList(b@)` de quien mira da 404 en todos los casos (el calendario compartido no se
suscribe solo) → **no** sirve para saber el permiso; se usa `accessRole` de `events.list`.

**Consecuencias para F1:**
- **Una sola llamada** (`events.list` con el token de quien mira) da el nivel (`accessRole`) **y**
  los eventos ya recortados por Google. `freeBusy` deja de hacer falta.
- Evento sin `summary` → se pinta «Ocupado». No hay que filtrar nada a mano: Google ya oculta.
- `accessRole ∈ {writer, owner}` → `can_schedule: true` (F3b).

### F1 — Servicio en el servidor
`app/services/google_calendar/coworker_calendar_service.rb`
- Entrada: integración de A (quien mira), integración de B (compañero), rango de fechas.
- (Ajustado tras F0) **una llamada:** `events.list` con token de A sobre `b.google_email`.
  - 200 → `access` según `accessRole`: `freeBusyReader` → `free_busy`; `reader` → `details`;
    `writer`/`owner` → `details` + `can_schedule: true`. Eventos limpios (id, título o nil,
    inicio, fin, todo el día); sin título → «Ocupado».
  - 404 notFound → `access: 'none'`.
  - Token de A o de B vencido (`invalid_grant`) → `access: 'reconnect'`.
- Errores de red/Google → `access: 'error'` (no tumba a los demás compañeros).
- Caché corta en Redis (2 min) por par A→B+rango, para no gastar la cuota de Google en cada
  cambio de semana.

```
   integración A ─┐
                  ├─► events.list(b@)
   correo de B  ──┘        │
          ┌────────────────┼──────────────────┬─────────────────┐
         404         accessRole=          accessRole=        accessRole=
          │        freeBusyReader          reader          writer / owner
          ▼               ▼                   ▼                   ▼
        none          free_busy            details        details + can_schedule
                  (Google ya quitó    (privados llegan
                    los títulos)         sin título)
```

#### F1 — HECHA (25/11/2026)

**Qué se hizo**
- `GoogleCalendarService#list_shared_events(calendar_id:, time_min:, time_max:)`: lee el
  calendario de otra persona con el token propio; devuelve `{ code:, access_role:, items: }`
  y **no** lanza en 404.
- `app/services/google_calendar_coworker_service.rb` (`GoogleCalendarCoworkerService`):
  `fetch(integración_compañero, time_min:, time_max:)` y `fetch_many(...)` →
  `{ agent_id, google_email, access, can_schedule, events: [{ id, summary, location, start, end, all_day, private }] }`.
  - `access`: `none` (404) · `free_busy` · `details` · `same_google` · `error`.
  - `can_schedule` = `accessRole` writer/owner.
  - Caché 2 min por par (quien mira → compañero → rango); `clear_cache_for(correo_dueño)`
    la invalida (lo usará F3c al cambiar un permiso).
  - Error con un compañero (403 cuota, red) → solo ese sale `error`.

**Cómo funciona** — nunca usa el token del compañero: por eso un compañero con permiso de
Google **vencido** (camion01) se puede ver igual si compartió; basta su correo. El estado
`reconnect` queda solo para **quien mira** (lo resuelve F2: sin token propio no hay nada).

**Pila de pruebas**
- `spec/services/google_calendar_coworker_service_spec.rb` — 10 casos (los niveles de F0,
  todo el día, 403, excepción, mismo Google, usa token de quien mira, caché).
  `POSTGRES_DATABASE=chatwoot_test bundle exec rspec spec/services/google_calendar_coworker_service_spec.rb spec/services/google_calendar_service_spec.rb` → 17/17.
- Contra Google real (cuenta 2, solo lectura): Admin → Andres = `none`, Admin → Jose Luis = `none`.

### F2 — Ruta en el servidor
- `GET /api/v1/accounts/:id/google_calendar/coworkers` → lista de compañeros de **la cuenta**
  con su estado (sin pedir eventos): conectado / sin conectar.
- `GET /api/v1/accounts/:id/google_calendar/coworkers/events?agent_ids[]=&start=&end=`
  → por agente: `{ agent_id, access, events | busy }`.
- Reglas: A debe tener Google conectado; solo agentes **de la cuenta actual**; A no se pide a sí mismo.
- `agent_events` (sin uso) se elimina.
- **D1:** qué pasa con `availability` (franjas de fondo de todos) — ver §7.

#### F2 — HECHA (25/11/2026)

**Qué se hizo**
- `CoworkersController` (`app/controllers/api/v1/accounts/google_calendar/coworkers_controller.rb`):
  - `GET /api/v1/accounts/:id/google_calendar/coworkers` → `{ coworkers: [{ agent_id, access,
    can_schedule, busy_now }], google_email }`. Todos los agentes de la cuenta menos quien mira;
    `access`: `not_connected` · `none` · `free_busy` · `details` · `same_google` · `error`.
    `busy_now` = algún evento con hora que cubre este momento (hoy, con caché de 2 min).
  - `GET …/coworkers/events?agent_ids[]=&start=&end=` → `{ coworkers: [{ agent_id, access,
    can_schedule, events }] }`. Ignora ids de otra cuenta. **No** devuelve correos de compañeros.
  - Sin Google conectado → 422; permiso de Google de quien mira vencido → 422 `{ error: 'reconnect' }`.
- **D1 aplicada** en `AvailabilityController`: misma forma de respuesta (la pantalla actual sigue
  funcionando), pero los compañeros se consultan con la conexión de quien mira → solo salen los
  que compartieron al menos libre/ocupado. Mi propio ocupado sigue saliendo (mi conexión, mi calendario).
- Se eliminó `events#agent_events` + su ruta + `getAgentEvents` del front (nadie lo usaba y leía
  el calendario ajeno con la conexión del dueño).
- Front: `GoogleCalendarAPI.getCoworkers()` y `getCoworkerEvents(agentIds, { start, end })`
  (los usa F3).

**Pila de pruebas**
- `spec/controllers/api/v1/accounts/google_calendar/coworkers_controller_spec.rb` — 8 casos:
  sesión, sin Google, reconectar, lista con niveles + `busy_now`, no expone correos, **solo arma la
  conexión de quien mira**, eventos filtrados por cuenta, `availability` D1.
  `POSTGRES_DATABASE=chatwoot_test bundle exec rspec spec/controllers/api/v1/accounts/google_calendar/coworkers_controller_spec.rb spec/services/google_calendar_coworker_service_spec.rb` → 18/18.
- En dev (puerto 3000, Admin #1, cuenta 2): `/coworkers` → Andres y Jose Luis `none`, #2 y #5
  `not_connected`; `/availability` → solo el propio ocupado de Admin (antes salían todos).

### F3 — Pantalla
- `api/googleCalendar.js`: `getCoworkers`, `getCoworkerEvents`.
- `store/modules/googleCalendar.js`: estado `coworkers`, `coworkerEvents`, `selectedCoworkerIds`.
- `AgendaWidget.vue`: sección «Compañeros» con casilla + estado + ayuda para «No compartido».
- `CalendarView.vue`: pinta eventos de compañeros (color por agente, `editable: false`,
  prefijo con el nombre) y bloques «Ocupado»; clic → ventanita solo lectura.
- Sin `?.` ni `??` en `<template>` (webpack 4); verificar «Compiled successfully».

### F3b — «Agendar a» un compañero (sin quedar en mi calendario)

Hoy (`CreateEventModal.vue`) el evento se crea siempre en un calendario de quien agenda y a los
demás solo se les invita por correo → quien crea queda como organizador y lo tiene en su
calendario.

```
  Modal «Crear evento»
  ┌────────────────────────────────────────────┐
  │ Agendar a:  [ Mí                       ▾ ] │
  │             ─────────────────────────────  │
  │             Mí                             │
  │             Beto       (puede agendarle)   │
  │             Caro       (puede agendarle)   │
  │             ── sin permiso ──  (gris)      │
  │             Dani  · pídele «Hacer cambios» │
  │ Calendario: [ Principal ▾ ]  ← solo si «Mí»│
  │ Título / Fecha / Hora / Invitados …        │
  └────────────────────────────────────────────┘
```

```
  A elige «Agendar a: Beto» y guarda
        │
        ▼
  POST /google_calendar/events  { agent_id: Beto, … }
        │
        ▼
  servidor: ¿A tiene accessRole writer/owner sobre beto@?  (F1, con caché)
        │
        ├─ sí ─► GoogleCalendarService(integración DE A)
        │         .create_event(calendar_id: beto@, …)   ← A NO se agrega como invitado
        │         → vive solo en el calendario de Beto
        │
        └─ no ─► 403 «Beto no te dio permiso de hacer cambios en su calendario»
```

- Servidor: `events#create` acepta `agent_id` opcional; si viene, valida que sea de la cuenta,
  que tenga Google conectado y que A tenga permiso de escritura (no confiar en la pantalla).
- `GET /coworkers` (F2) devuelve también `can_schedule: true/false` por compañero.
- Pantalla: select nativo «Agendar a»; con un compañero elegido se oculta «Calendario»
  (siempre su principal) y el evento recién creado se ve en «Compañeros» si Beto está palomeado.
- Mismo Google (#1 y #4): «Agendar a» al otro = agendarse a sí mismo → se oculta de la lista.
- Fuera de esta fase: **editar, mover o borrar** eventos del compañero.

### F3c — «Compartir mi calendario» desde el sistema

Google permite administrar con quién se comparte un calendario (reglas de acceso, ACL) con el
permiso que ya pedimos (`auth/calendar`). **Solo el dueño** puede cambiarlas → cada agente, con
SU conexión, decide quién lo ve y quién le agenda. Va y viene con Google: lo que se cambie aquí
se ve en calendar.google.com y al revés.

```
  Calendario → «Compartir mi calendario»  (agente Andres)
  ┌──────────────────────────────────────────────────────────┐
  │ Compañero        Permiso                                 │
  │ Admin            [ Ver todos los detalles        ▾ ]     │
  │ Jose Luis        [ Nada                          ▾ ]     │
  │                    Nada                                  │
  │                    Solo libre/ocupado                    │
  │                    Ver todos los detalles                │
  │                    Hacer cambios (puede agendarme)       │
  └──────────────────────────────────────────────────────────┘
        │  conexión DE Andres (dueño)
        ▼
  Google ACL de su calendario principal (regla «user:<correo del compañero>»)
     Nada            → DELETE  /calendars/primary/acl/user:<correo>
     Solo ocupado    → role = freeBusyReader
     Detalles        → role = reader
     Hacer cambios   → role = writer
     (insert/patch con sendNotifications=false: sin correo de aviso)
```

- Servidor: `GET /google_calendar/sharing_rules` (lee la ACL y la cruza con los compañeros de la
  cuenta) y `PUT /google_calendar/sharing_rules/:agent_id { level }`.
  Nombre distinto de `sharing` (ese es «mandar mi agenda a un contacto» y no cambia).
- Servicio: `GoogleCalendarService#list_acl`, `#upsert_acl_rule(email, role)`, `#delete_acl_rule(email)`.
- Solo compañeros **de la cuenta** con Google conectado; nunca el propio correo.
- Reglas que no son de compañeros (otras personas, dominio, público) **no se muestran ni se tocan**.
- Si Google rechaza (p. ej. Workspace que prohíbe compartir afuera) → aviso con el motivo.
- Mismo Google en dos agentes → ese compañero no sale en la lista.
- Al cambiar un permiso se limpia la caché de F1 de ese par.
- Orden de trabajo: F3c antes que «Compañeros» y «Agendar a» en la pila de pruebas
  (primero se comparte, luego se ve y se agenda).

### F4 — Textos
- `es` / `en` en `GOOGLE_CALENDAR.COWORKERS.*`. Español de México con tú. Nada de «Chatwoot».

### F5 — Pruebas automáticas
Con `POSTGRES_DATABASE=chatwoot_test`:
- Servicio: 4 casos (details / free_busy / none / error) con respuestas de Google simuladas.
- Controlador: no deja ver agentes de otra cuenta; pide Google conectado; arma la respuesta por agente.

### F6 — Pila de pruebas en navegador (con tus dos cuentas)
1. B comparte «Ver todos los detalles» con A → A palomea a B → ve títulos.
2. B cambia a «Ver solo libre/ocupado» → A ve solo «Ocupado» (máx. 2 min por la caché).
3. B quita el permiso → A ve «No compartido».
4. Evento privado de B con detalles compartidos → A lo ve como «Ocupado».
5. Eli sin conectar → «Sin conectar», sin casilla activa.
6. A desconecta su Google → aviso para conectar; no se ve a nadie.
7. Evento de B: no se arrastra, no se edita, no se borra.
8. El bot de IA sigue agendando igual en una conversación de prueba (inbox 493).
9. B da «Hacer cambios» a A → A «Agendar a: B» → el evento aparece en Google de B y **no** en el de A.
10. B baja el permiso a «Ver detalles» → B sale de «Agendar a»; forzar la llamada → 403.
11. Desde «Compartir mi calendario», B da cada nivel a A → en calendar.google.com de B se ve igual.
12. B cambia el permiso en calendar.google.com → «Compartir mi calendario» lo muestra al recargar.
13. Reglas ajenas (otra persona / público) siguen intactas tras cambiar las de compañeros.

---

## 7. Decisiones (todas tomadas 25/11/2026)

| #  | Pregunta | Decisión |
|----|----------|----------|
| D1 | Franjas «ocupado de todos» que se ven hoy | **Respetan lo compartido**: solo salen de quien compartió al menos «Solo libre/ocupado» (token de quien mira). |
| D2 | ¿Qué calendarios del compañero? | **Solo el principal** (su correo). Secundarios: después, si se piden. |
| D3 | Si B da «Hacer cambios», ¿A puede agendarle? | **Sí, crear** en el calendario de B (F3b), sin quedar en el de A. Editar/mover/borrar: otro paso. |
| D4 | ¿A quién se ve y se comparte? | **Todos los agentes de la cuenta** con Google conectado. |
| D5 | Google Workspace | **Se respeta lo que diga Workspace**; si Google rechaza compartir, se muestra su motivo. |

## 8. Riesgos

- **Cuota de Google:** 1–2 llamadas por compañero palomeado por cada cambio de rango → la caché
  de 2 min y pedir solo los palomeados lo mantiene bajo.
- **Correo distinto:** si B conectó un Google distinto al que comparte, A no lo verá. Se usa
  siempre `google_email` de la integración de B.
- **Nunca probado contra Google real** hasta F0/F6: los formatos exactos de respuesta se
  confirman en F0.
