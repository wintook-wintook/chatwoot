# Ver el calendario de los compañeros (respetando lo que cada uno comparte en Google)

> Rama: `fix/calendario_google` (desde `origin/develop` 92fb814b) · Plan v1.0 · 25/11/2026
> Estado: **solo plan** — no se programa nada hasta el OK.

---

## 1. Qué se pide

Entre los agentes de una misma cuenta, poder **revisar la agenda de un compañero** desde la
pantalla del calendario, **siempre y cuando ese compañero lo permita** en la configuración de
su Google Calendar («Compartir con personas específicas»).

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
  «Hacer cambios…» / «Administrar»    Detalles               igual (solo lectura aquí)
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
| No compartido        | ¿404 notFound?                       | ¿`errors: notFound`?          |

Se anota lo que responde de verdad; F1 se ajusta a eso. **Necesito tu OK y las dos cuentas.**

### F1 — Servicio en el servidor
`app/services/google_calendar/coworker_calendar_service.rb`
- Entrada: integración de A (quien mira), integración de B (compañero), rango de fechas.
- Paso 1: `events.list` con token de A sobre `b.google_email`.
  - Responde con detalles → `access: 'details'`, eventos limpios (título, inicio, fin, todo el día).
  - Sin acceso a detalles → paso 2.
- Paso 2: `freeBusy` con token de A sobre `b.google_email`.
  - Con bloques → `access: 'free_busy'`, `busy: [...]`.
  - `errors` / notFound → `access: 'none'`.
- Errores de red/Google → `access: 'error'` (no tumba a los demás compañeros).
- Caché corta en Redis (2 min) por par A→B+rango, para no gastar la cuota de Google en cada
  cambio de semana.

```
   integración A ─┐
                  ├─► events.list(b@) ──ok──► details
   correo de B  ──┘         │
                        sin acceso
                            ▼
                      freeBusy(b@) ──bloques──► free_busy
                            │
                         notFound
                            ▼
                           none
```

### F2 — Ruta en el servidor
- `GET /api/v1/accounts/:id/google_calendar/coworkers` → lista de compañeros de **la cuenta**
  con su estado (sin pedir eventos): conectado / sin conectar.
- `GET /api/v1/accounts/:id/google_calendar/coworkers/events?agent_ids[]=&start=&end=`
  → por agente: `{ agent_id, access, events | busy }`.
- Reglas: A debe tener Google conectado; solo agentes **de la cuenta actual**; A no se pide a sí mismo.
- `agent_events` (sin uso) se elimina.
- **D1:** qué pasa con `availability` (franjas de fondo de todos) — ver §7.

### F3 — Pantalla
- `api/googleCalendar.js`: `getCoworkers`, `getCoworkerEvents`.
- `store/modules/googleCalendar.js`: estado `coworkers`, `coworkerEvents`, `selectedCoworkerIds`.
- `AgendaWidget.vue`: sección «Compañeros» con casilla + estado + ayuda para «No compartido».
- `CalendarView.vue`: pinta eventos de compañeros (color por agente, `editable: false`,
  prefijo con el nombre) y bloques «Ocupado»; clic → ventanita solo lectura.
- Sin `?.` ni `??` en `<template>` (webpack 4); verificar «Compiled successfully».

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

---

## 7. Decisiones abiertas

| #  | Pregunta | Recomendación |
|----|----------|---------------|
| D1 | Las franjas de fondo «ocupado de todos» que se ven hoy, ¿se quitan o también respetan lo compartido? | **Que respeten lo compartido** (pasan a usar el token de A). Si no, seguiría viéndose el ocupado de quien no compartió nada. |
| D2 | ¿Solo el calendario principal del compañero o también los secundarios que comparta? | **Solo el principal** en esta versión. |
| D3 | Si B da «Hacer cambios», ¿A puede editar desde aquí? | **No, solo lectura.** Sería otro paso. |
| D4 | ¿Mostrar compañeros de todos los agentes de la cuenta o solo de un equipo? | **Todos los de la cuenta** que tengan Google conectado. |
| D5 | Google Workspace: el administrador puede dejar que todos vean el libre/ocupado de todos sin compartir. | Se respeta tal cual (es la configuración de Google de esa empresa). Solo se avisa. |

---

## 8. Riesgos

- **Cuota de Google:** 1–2 llamadas por compañero palomeado por cada cambio de rango → la caché
  de 2 min y pedir solo los palomeados lo mantiene bajo.
- **Correo distinto:** si B conectó un Google distinto al que comparte, A no lo verá. Se usa
  siempre `google_email` de la integración de B.
- **Nunca probado contra Google real** hasta F0/F6: los formatos exactos de respuesta se
  confirman en F0.
