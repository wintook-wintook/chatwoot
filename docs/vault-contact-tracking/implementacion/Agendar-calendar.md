---
titulo: "@agendar_calendar — agendar/consultar/mover/cancelar citas en Google Calendar"
tipo: implementacion
tags: [contact-tracking, directivas, calendar, google-calendar, citas, appointment-aware, multi-calendario]
---

# `@agendar_calendar` — citas en Google Calendar

Directiva del **Entrenamiento** (`complementary_prompt`) que habilita al Agente IA a
**agendar, consultar, mover y cancelar** citas en **Google Calendar** durante la
conversación. Es "appointment-aware": el LLM recibe el **estado real de la cita** y
decide una **acción concreta**, en vez de agendar a ciegas.

> Ver la directiva como token en [[Directivas-complementary-prompt]], los servicios en
> [[Servicios-y-jobs]] y los casos de prueba en [[Testeo-funcional]] (TC-05/06/06b).

---

## Activación (el "gate")

En `ContactTrackingResponseAnalyzerJob#try_kbase_then_conversational` la lógica de cita
corre **solo si** se cumplen **ambas**:

1. **Directiva presente** — el prompt contiene `@agendar_calendar` (`agendar_calendar_directive?`).
2. **Calendario configurado** — el Agente IA (o el tracking) tiene `calendar_integration_ids`
   (`calendar_configured?`).

Orden de prioridad del bot al responder:

```
KBase  →  @crear_ticket  →  @agendar_calendar  →  respuesta conversacional
```

> La directiva `@agendar_calendar` **se quita del prompt** antes de pasárselo al LLM
> conversacional, para que no la "actúe" literalmente.
> Todo el flujo entra por este gate porque `TRACKING_DETECT_INTENT` está en `false` por defecto.

---

## El cerebro: clasificación appointment-aware

`appointment_state_summary` arma un texto legible del estado:

- *"El contacto NO tiene ninguna cita agendada todavía."*
- *"El contacto YA tiene una cita agendada para el lunes 15 de junio a las 09:00."*

Ese estado + los últimos 4 mensajes van al `RouterService`, que devuelve un
**`appointment_action`**:

| `appointment_action` | El LLM lo elige cuando… |
|----------------------|--------------------------|
| `query`    | el cliente **pregunta por su cita** ya agendada ("¿cuándo es mi cita?") |
| `book_new` | quiere agendar una cita **nueva** |
| `move`     | quiere **cambiar fecha/hora** de su cita existente |
| `cancel`   | quiere **anular** su cita existente |
| `null`     | **no** está hablando de una cita → sigue a respuesta conversacional |

> **Regla clave (no "eager"):** `appointment_action` es `null` salvo que el cliente
> realmente hable de una cita. Si es `null`, **no se dispara nada** de calendario.

---

## Despacho de la acción

`dispatch_appointment_action` — con `has_appt = (appointment_event_id && appointment_at)`:

| Acción | Tiene cita | No tiene cita |
|--------|-----------|----------------|
| `query`    | **recuerda** la cita existente | agenda una nueva |
| `move`     | reagenda (`handle_reschedule`) | agenda una nueva |
| `cancel`   | cancela (`handle_cancel_appointment`) | cancela (no-op) |
| `book_new` | — | agenda una nueva |

Caso estrella (TC-06b): **ya tiene cita y pregunta "¿cuándo es mi cita?"** →
`inform_existing_appointment` responde *"Ya tenés una cita agendada para el {fecha}. 📅
Puedo moverla o cancelarla. ¿Qué preferís?"* — **no re-ofrece horarios**.

---

## Diagrama de flujo

```
                 mensaje entrante del contacto
                              │
                  ResponseAnalyzerJob
                              │
                  ┌───────────┴───────────┐
                  │  try_kbase_then_       │
                  │  conversational        │
                  └───────────┬───────────┘
                              │
        ┌──────────┬──────────┼───────────────┐
     KBase?    @crear_ticket?  │            (sigue)
     responde   crea ticket    ▼
        ✓          ✓     ¿@agendar_calendar  ── NO ──► respuesta
                          y calendario?               conversacional
                              │ SÍ
                              ▼
                 ┌─────────────────────────────┐
                 │ appointment_state_summary   │  "tiene cita el X" /
                 │  (estado real al LLM)        │  "no tiene cita"
                 └──────────────┬──────────────┘
                                ▼
                        RouterService.classify
                          → appointment_action
                                │
        ┌──────────┬────────────┼────────────┬───────────┐
      null       query         move        cancel     book_new
        │          │             │            │            │
        ▼     ┌────┴────┐   ┌────┴────┐       ▼            ▼
   respuesta  │tiene?   │   │tiene?   │    cancel      ¿tiene cita?
   conversac. │ sí: info│   │ sí:mover│   appointment   sí → info
              │ no:book │   │ no:book │                 no → buscar slots
              └─────────┘   └─────────┘                       │
                                                              ▼
                                              AvailabilitySlotService.call
                                              (working_hours + freeBusy)
                                                              │
                                            ┌─────────────────┴───────────┐
                                         hay slots                    sin slots
                                            │                             │
                                            ▼                             ▼
                                     offer_slots                  pausa + nota
                                  [PENDING_SLOT]                 "atención humana"
                                            │
                              cliente elige  ▼
                                  [PENDING_EMAIL] → email
                                            │
                                            ▼
                              confirm_and_create_appointment
                                  → crea/mueve evento en el calendario libre
                                  → guarda appointment_event_id
                                    + appointment_calendar_id (cuenta)
                                    + appointment_calendar_gid (calendario)
                                  → invitación por correo (sendUpdates=all)
```

---

## Reglas de horarios (Opción A — desde el inbox)

`AvailabilitySlotService` decide qué slots son válidos:

- **Si el inbox tiene `working_hours_enabled?`** (`working_hours_for`): usa los
  **horarios laborales reales del inbox** (`WorkingHour` por día de semana, en la zona
  del inbox). Días cerrados (`closed_all_day`) → sin disponibilidad.
- **Si no:** default **9–18, lunes a viernes**.
- Slots de duración `calendar_event_duration` (default **30 min**).
- Respeta el `freeBusy` de Google (no choca con ocupados).
- Reparte entre varios **recursos** sin repetir horario; **máximo 5 slots** (ver multi-calendario abajo).

---

## Agendas y calendarios destino (multi-calendario)

El Agente IA puede agendar en **varias cuentas** de Google y, dentro de cada una, en
**varios calendarios**. La clave del modelo:

> **Cada calendario marcado es un "recurso" independiente.** El bot mira la disponibilidad
> de **todos** y crea la cita en el que esté libre; si varios están libres a la misma hora,
> **reparte** (round-robin por `balance_slots`).

### Configuración (en el Agente IA / template)

- `calendar_integration_ids` (jsonb `[]`) — qué **cuentas** de Google están vinculadas.
- `booking_calendar_ids` (jsonb `{}`) — mapa `{ integration_id => [google_calendar_id, …] }`:
  en qué calendarios de cada cuenta se puede agendar. **Sin entrada para una cuenta → modo
  legado**: lee la unión de sus `enabled_calendar_ids` y crea en `primary` (comportamiento previo).

En la UI (tab **Agendas**): un **modal con árbol** agrupado por cuenta (su calendario
**Primario** + sus **Secundarios**, con casillas) y una **lista consolidada** de los
seleccionados con opción de **quitar**. Una cuenta queda vinculada cuando tiene ≥1 calendario
marcado.

### Cómo se calcula y se crea

`AvailabilitySlotService` (`resources_for`) convierte cada `(cuenta, calendario)` en un
recurso `{ gcal:, read: }`:

- **Modo configurado:** un recurso por calendario marcado → `read = [gcal]` (cada calendario
  solo bloquea su **propia** ocupación).
- **Modo legado:** un recurso por cuenta → `read = enabled_calendar_ids`, `gcal = 'primary'`.

Cada slot lleva `calendar_integration_id` **y** `google_calendar_id`. Al confirmar, el evento
se crea en ese `google_calendar_id` y se guarda en `appointment_calendar_gid` (para mover/cancelar
en el calendario correcto).

> ⚠️ **Cuidado:** como cada calendario marcado solo se bloquea a sí mismo, marcar **varios
> calendarios de la MISMA persona** permite citas en paralelo a la misma hora (correcto si son
> recursos separados como *sillones/salas*; no si es una sola persona). Para un mismo profesional,
> marcá **un solo calendario**.

---

## Interpretación de la fecha/hora pedida

El `RouterService` llena `reschedule_data` con lo que pidió el cliente. La regla de oro:
**el LLM entiende el lenguaje, Ruby calcula las fechas** (el modelo es poco confiable con
aritmética de calendario).

| Pedido del cliente | Campo del router | Resolución |
|--------------------|------------------|------------|
| "el martes", "next Tuesday", "terça" | `weekday` (1=lunes … 7=domingo, ISO) | Ruby calcula la **próxima ocurrencia** de ese día (`weekday_to_date`). Idioma-neutro. |
| "en dos semanas", "la semana que viene" | `weeks_ahead` (entero) | Suma semanas a la próxima ocurrencia. Solo si es explícito. |
| "el 30 de junio", "5/7" | `specific_date` (YYYY-MM-DD) | Fecha de calendario explícita. `weekday` tiene prioridad si ambos vienen. |
| "a las 16:00", "4 de la tarde" | `specific_time` (HH:MM) | Hora exacta → intenta ese horario puntual. |
| "por la mañana/tarde/noche" | `time_of_day` (morning/afternoon/evening) | Franja sin hora exacta. |

- **Días de semana → determinístico:** "el próximo martes" desde un miércoles = el martes
  más cercano (no el de la semana siguiente). Si hoy ES ese día, va al de la semana próxima.
  `weekday` gana sobre `specific_date` aunque el LLM redundante mande una fecha mal.
- **Franja horaria** (`time_of_day`): la búsqueda se **ancla al inicio de la franja**
  (tarde→12:00, noche→18:00, mañana→inicio del día) vía `booking_search_anchor`, así los
  primeros slots disponibles caen dentro de la franja pedida. Franjas: **mañana <12, tarde
  12–18, noche ≥18**.
- **Hora exacta libre** → la confirma directo (pide email si falta). **Hora exacta ocupada**
  o **solo día/franja** → ofrece los horarios de ese día/franja para que elija.

---

## Presentación de horarios (configurable)

Cómo el bot **lista los horarios** al cliente se elige en el Agente IA con
`slots_presentation` (string, default `detailed`). `format_slots_lines` ramifica según el
valor. **La numeración 1-5 siempre refleja la posición en `slots`**, así la elección por
número del cliente sigue mapeando bien sin importar el agrupamiento.

| Valor | Estilo | Ejemplo |
|-------|--------|---------|
| `detailed` *(default)* | Todo en cada línea | `1️⃣ jueves 25 jun · 09:00 – 10:00 hs (hora de Mexico City) — Admin` |
| `by_agent` | Agrupado por agenda (encabezado profesional + zona) | `👤 Admin (hora de Mexico City)` ↵ `   1️⃣ jueves 25 jun · 09:00 – 10:00 hs` |
| `simple` | Sin zona ni profesional | `1️⃣ jueves 25 jun · 09:00 – 10:00 hs` |
| `by_day` | Agrupado por día, solo hora de inicio | `📅 jueves 25 jun` ↵ `   1️⃣ 09:00   2️⃣ 10:00` |

> En `by_agent`/`by_day` la numeración puede quedar **no contigua** dentro de un grupo
> (ej. Admin = 1️⃣2️⃣4️⃣5️⃣, otro = 3️⃣): es correcto, cada número sigue apuntando a su slot.
> Default `detailed` = comportamiento histórico (no cambia nada existente).

---

## Zona horaria (anclada a Google)

`appointment_timezone` — prioridad:

1. **Zona real de Google Calendar** (`google_calendar_timezone`): lee
   `GET /users/me/settings/timezone`, cacheada **12 h en Redis** (`gcal_tz::<cal_id>`).
2. → zona del Agente IA (`tracking_template.timezone`)
3. → zona del inbox
4. → `America/Mexico_City`

> **Por qué:** Google muestra los eventos en la zona de la **cuenta del usuario**, sin
> importar con qué `timeZone` se creó el evento. Anclando a esa zona, **la hora del chat
> = la hora que ve el contacto en su calendario**. Los horarios ofrecidos se muestran con
> **etiqueta de zona** explícita (ej. "(hora de México)") vía `timezone_label`.

---

## Estado / máquina de turnos

Marcadores en `ai_context`:

- `[PENDING_SLOT]` — se ofrecieron horarios, esperando que el cliente elija.
- `[PENDING_EMAIL]` — esperando el email para la invitación.

Al confirmar (`confirm_and_create_appointment`):

- Crea el evento en el `google_calendar_id` del slot (o lo **mueve** si ya existía en ese mismo
  calendario: `create_or_move_calendar_event`; si cambió de calendario, crea nuevo + borra el viejo).
- Guarda `appointment_event_id` + `appointment_calendar_id` (cuenta) + `appointment_calendar_gid`
  (calendario de Google real) — necesarios para mover/cancelar en el lugar correcto.
- Envía la invitación por correo a todos los invitados (`sendUpdates=all`, cualquier dominio).

---

## Manejo de bordes

- **Sin calendarios vinculados** (`handle_no_calendar_configured`): mensaje claro, pausa el
  tracking, marca `interested`, avisa al admin y deja nota privada → coordinación manual.
- **Sin disponibilidad** (`book_appointment_no_slots`): misma pausa + nota "requiere
  atención humana".
- **Ya tiene cita y pide otra**: nunca duplica; recuerda la existente y ofrece mover/cancelar.

---

## Ejemplo real anotado (conversación #49)

Caso real de punta a punta (hoy = miércoles 24/06, zona México). Muestra reservar con
día+franja, elegir, mover por franja, consultar y conversar — todo en un mismo hilo.

| # | Cliente | Bot | Qué pasó por dentro |
|---|---------|-----|---------------------|
| 1 | "Quiero una cita **por la tarde el día martes**" | Ofrece *martes 30 jun · 12:00 / 13:00 / 14:00…* | `book_new`. `weekday=2` → Ruby resuelve **martes 30** (no el de la otra semana). `time_of_day=afternoon` → búsqueda anclada a **12:00**. Ofrece slots de la tarde. `[PENDING_SLOT]` |
| 2 | "**4**" | "📧 ¿A qué correo…?" | Elección por número (`handle_slot_selection`). Sin email guardado → `[PENDING_EMAIL]` |
| 3 | "aliverio.mx@gmail.com" | "✅ Tu cita está agendada para el **martes 30 a las 15:00–16:00**" | `confirm_and_create_appointment` → crea el evento en Google, guarda `appointment_event_id`, manda invitación |
| 4 | "Mi cita la puedo **cambiar por la mañana**" | "✅ Tu cita está agendada para el **martes 30 a las 09:00–10:00**" | `move` con `time_of_day=morning`. Mueve el **mismo evento** de Google (no duplica) a un horario de la mañana |
| 5 | "**recuérdame cuándo es la cita**" | "Ya tenés una cita agendada para el **martes 30 a las 09:00**. Puedo moverla o cancelarla." | `query` → `inform_existing_appointment` (no re-ofrece horarios) |
| 6 | "Quiero un servicio… **¿qué ofrecen?**" | Lista de servicios | `appointment_action=null` → **respuesta conversacional** (no toca el calendario) |
| 7 | "ese día quiero una **endodoncia**" | "Ya tenés una cita el martes 30 a las 09:00…" | El LLM lo asocia a la cita existente → `query` → recuerda la cita |
| 8 | "Gracias" | "¡De nada! Te esperamos el martes 30 a las 09:00 para tu endodoncia 🦷" | Cierre conversacional, con la cita en contexto |

**Lo que valida este hilo:** resolución determinística del día (#1), franja al reservar (#1)
y al mover (#4), selección por número (#2), creación y **movimiento del mismo evento** en
Google (#3/#4), consulta de cita existente sin re-ofrecer (#5/#7), y convivencia con
respuestas no-cita (#6) — todo bajo la misma directiva `@agendar_calendar`.

---

## Archivos

- `app/jobs/contact_tracking_response_analyzer_job.rb` — orquestador (gate, clasificación,
  despacho, handlers, zona horaria).
- `app/services/contact_trackings/router_service.rb` — `appointment_action` + estado al LLM.
- `app/services/contact_trackings/availability_slot_service.rb` — slots, working_hours, freeBusy,
  **recursos por (cuenta, calendario)** (`resources_for`, `balance_slots`).
- `app/services/google_calendar_service.rb` — CRUD de eventos (con `calendar_id`) + `account_timezone`
  + `list_calendars`.
- `app/controllers/api/v1/accounts/tracking_templates_controller.rb` — `calendar_integrations`
  (devuelve calendarios escribibles por cuenta) + params `booking_calendar_ids` / `slots_presentation`.
- `app/javascript/.../trackingTemplates/EditTemplate.vue` — tab Agendas: modal árbol, lista con
  quitar, selector de presentación.

Relacionado: [[Servicios-y-jobs]] · [[Directivas-complementary-prompt]] · [[Testeo-funcional]] · [[Ciclo-de-vida]]
