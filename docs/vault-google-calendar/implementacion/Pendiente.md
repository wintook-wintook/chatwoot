---
titulo: Pendiente — Google Calendar
tipo: pendiente
tags: [google-calendar, pendiente]
---

# Pendiente — Google Calendar

Tareas abiertas del módulo. Ver también [[Estado-actual]] y
[[Gestion-cuentas-y-calendarios]] (aún por escribir).

## Hecho
- [x] **Crear/editar citas eligiendo el calendario** (principal o secundario propio).
  Antes toda cita creada desde Chatwoot iba al **principal** (`primary`). Ahora:
  - `CreateEventModal.vue` tiene un **selector de calendario** (solo calendarios con
    permiso `owner`/`writer`, el Principal primero; se oculta si hay uno solo).
  - `events_controller#create` y `#update` reciben `calendar_id` (default `primary`).
  - Los eventos llevan su `calendarId` en `extendedProps` → **editar y arrastrar**
    impactan el calendario correcto, no siempre el principal.
  - Rama `fix/google_calendar`.

## Pendiente
- [ ] **Mover un evento entre calendarios al editar**: hoy el selector queda
  **deshabilitado** en edición (cambiar de calendario requiere la API `events.move`
  de Google, no un simple `update`).
- [ ] **Colorear los eventos del grid por su calendario**: hoy el color sale de un
  hash del id del evento (`eventColor` en `CalendarView.vue`), no del
  `background_color` del calendario. Los colores por calendario solo se ven en los
  checkboxes del panel lateral (`AgendaWidget`), no en los eventos del `FullCalendar`.
- [ ] **Filtro "mostrar solo uno" — matiz**: si no dejas **ningún** calendario
  marcado, el backend cae a `primary` (no a "nada") y la UI los muestra todos como
  activos (`enabledIds` vacío = todos). El filtrado real ocurre al seleccionar un
  subconjunto. Evaluar si se quiere un estado "ninguno visible" explícito.
- [ ] **Ver detalle de eventos de otros agentes**: hoy `events#agent_events` solo
  devuelve **free/busy** de los demás (no título ni invitados), a propósito por
  privacidad. Los propios sí se ven completos. Evaluar si algún rol (admin) debería
  ver más.
- [ ] **Verificar en vivo el prellenado al editar**: se agregó `extendedProps`
  (descripción, ubicación, invitados) en `CalendarView.syncEvents`; confirmar en
  navegador que el modal de edición ahora sí prellena esos campos (antes quedaban
  vacíos).
- [ ] **Ubicación (location)**: el campo existe en el form pero su input está
  comentado en el template (pendiente integración Google Maps Places API).

## Notas
- Cada **agente** conecta **su propia** cuenta Google (`UserCalendarIntegration` por
  `user + account`); la disponibilidad de la cuenta agrega la de todos los agentes.
- Confirmar siempre contra el código antes de asumir que algo falta.
