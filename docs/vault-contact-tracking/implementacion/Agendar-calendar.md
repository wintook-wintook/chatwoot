---
titulo: "@agendar_calendar — agendar/consultar/mover/cancelar citas en Google Calendar"
tipo: implementacion
tags: [contact-tracking, directivas, calendar, google-calendar, citas, appointment-aware]
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
                                  → crea/mueve evento en Google
                                  → guarda appointment_event_id
                                    + appointment_calendar_id
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
- Reparte entre varios agentes sin repetir horario; **máximo 5 slots**.

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

- Crea el evento (o lo **mueve** si ya existía: `create_or_move_calendar_event`).
- Guarda `appointment_event_id` + `appointment_calendar_id` (para mover/cancelar luego).
- Envía la invitación por correo a todos los invitados (`sendUpdates=all`, cualquier dominio).

---

## Manejo de bordes

- **Sin calendarios vinculados** (`handle_no_calendar_configured`): mensaje claro, pausa el
  tracking, marca `interested`, avisa al admin y deja nota privada → coordinación manual.
- **Sin disponibilidad** (`book_appointment_no_slots`): misma pausa + nota "requiere
  atención humana".
- **Ya tiene cita y pide otra**: nunca duplica; recuerda la existente y ofrece mover/cancelar.

---

## Archivos

- `app/jobs/contact_tracking_response_analyzer_job.rb` — orquestador (gate, clasificación,
  despacho, handlers, zona horaria).
- `app/services/contact_trackings/router_service.rb` — `appointment_action` + estado al LLM.
- `app/services/contact_trackings/availability_slot_service.rb` — slots, working_hours, freeBusy.
- `app/services/google_calendar_service.rb` — CRUD de eventos + `account_timezone`.

Relacionado: [[Servicios-y-jobs]] · [[Directivas-complementary-prompt]] · [[Testeo-funcional]] · [[Ciclo-de-vida]]
