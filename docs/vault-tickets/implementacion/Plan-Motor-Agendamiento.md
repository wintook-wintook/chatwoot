# Plan — Motor de agendamiento («Tipos de cita»)

> Estado: 📝 **plan, sin empezar** (2026-11-27). Pedido por el usuario después de la demo de la estética:
> «con el tema de agendar, ¿no deberíamos tener un motor especial para eso, ya que hay varias configuraciones?».
> Se hace **después de la demo**, en su propia rama. No toca «Agentes a medida» (1.0).

## 1. Para qué

Hoy agendar es **una sola pieza** del motor 2.0 (`Motor2::Skills::Appointments`), pero **cada agente trae su
propia configuración** de citas. Una empresa con dos agentes (prospectos y clientes) configura lo mismo dos veces
y puede quedar distinto. Además faltan cosas que todo negocio de citas necesita (horario de cada persona, tiempo
entre citas, quién hace qué servicio).

La idea: **«Tipos de cita»** configurados una vez en la cuenta (como los «event types» de Calendly / Cal.com) y un
**motor de agendamiento** que los usa. Los agentes solo eligen **qué tipos agendan y cuándo ofrecerlos**.

## 2. Cómo está hoy (lo que se junta)

| Dónde | Qué se configura hoy | Código |
|---|---|---|
| Atención a prospectos › Al calificar | con quién (`appointment_user_ids`), minutos, tipo (llamada/videollamada/visita/oficina), lugar, **citas de servicio** | `Functions::Prospects#appointments` |
| Atención a clientes › Comercial | demo / visita / **citas de servicio** (`booking`), personas, minutos | `Functions::Customers#appointments`, `CustomerAreas` |
| Atención a clientes › Soporte | visita técnica: personas, minutos | `Customers#technical_visit` |
| Vendedor de campaña (Ofrecer/Reactivar, meta «cita») | personas, minutos; recordatorio de la campaña | `Functions::CampaignSeller`, `TrackingCampaigns::AppointmentReminder` |
| Los tres agentes › Seguimiento | recordatorio de la cita y plantilla (`appointment_notice`) | `Functions::Extras`, `Motor2::AppointmentNotice` |
| La bandeja | horario de atención = horario de citas | `Inbox#working_hours` |
| Catálogo | duración de cada servicio (`catalog_items.duration_minutes`) | `Skills::AppointmentServices` |
| Ficha 1.0 | `tracking_templates.calendar_integration_ids`, `calendar_event_duration` | (lo usan también los agentes a medida: **no se toca**) |

Piezas que ya existen y se reutilizan:
- **Disponibilidad:** `ContactTrackings::AvailabilitySlotService` (Google free/busy, horario por días, reparte
  entre personas, calendarios por recurso `booking_calendars`, `slot_for`, `calendars_unreadable?`).
- **La cita:** `CaseMeeting` + `AgendaItems::Creator` + `Cases::MeetingSyncJob` / `GoogleMirrorService` (evento en
  Google, cancelar, mover).
- **Conversación:** `Skills::Appointments`, `AppointmentList` (varias citas, para otra persona),
  `AppointmentChanges` (mover/cancelar), `AppointmentServices` (duración por servicio, «con quién»),
  `Motor2::SlotPick` («10», «el primero»).
- **Después:** `Motor2::AppointmentNotice` (recordatorio y «no llegó»), `ReminderWriter`.

## 3. Lo que falta (por qué un motor)

1. **Configuración repetida** en cada agente (y en cada campaña).
2. **Horario por persona:** hoy todos usan el de la bandeja (o 9–18 L–V). Karla trabaja martes a sábado; John
   solo en la mañana.
3. **Qué servicios hace cada quien:** Mariana no hace uñas.
4. **Reglas de agenda:** tiempo entre citas (limpiar la cabina), anticipación mínima («no con menos de 2 h») y
   máxima («hasta 30 días»), máximo de citas por día y por persona, días festivos / vacaciones.
5. **Recursos que no son personas:** una cabina, un sillón, un consultorio, una grúa (dos personas no pueden usar
   la misma cabina a la vez).
6. **Políticas** por tipo: anticipo, cancelar o mover con 24 h, tolerancia de llegada, qué traer.
7. **Datos antes de agendar** por tipo (nombre, teléfono, placas del auto…), hoy solo en prospectos.
8. **Fuera de los agentes:** Dali, la Agenda a mano y una futura página pública de reservas deberían agendar
   con las mismas reglas.
9. **Reportes de citas:** cuántas por tipo, ocupación por persona, «no llegó», canceladas, de qué agente vienen.

## 4. Modelo

### 4.1 `appointment_types` (tipo de cita) — por cuenta
| Campo | Qué es |
|---|---|
| `name`, `description`, `active`, `color` | «Cita en estética», «Demo», «Visita técnica» |
| `duration_mode` | `fixed` (minutos) · `services` (suma de `duration_minutes` del Catálogo) |
| `minutes` | duración fija o la de un servicio sin duración |
| `catalog_category_ids` / `catalog_item_ids` | qué servicios se agendan con este tipo (si `services`) |
| `modality` | `in_person` (en el lugar) · `call` · `video` · `on_site` (a domicilio: pide dirección) |
| `location`, `meeting_link_mode` | dirección / liga fija / Google Meet automático |
| `assignment` | `any` (el primero libre) · `round_robin` (reparte) · `customer_choice` (puede pedir con quién) |
| `buffer_before`, `buffer_after` | minutos libres antes y después |
| `min_notice_minutes`, `max_days_ahead`, `max_per_day` | anticipación y tope |
| `slot_step_minutes` | cada cuánto se ofrecen horarios (15/30/60) |
| `required_contact` [] | datos que pide antes de ofrecer horarios |
| `policy_text` | lo que se le dice al confirmar (anticipo, cancelar con 24 h, llegar 5 min antes) |
| `reminder` {on, hours_before, template} | recordatorio (hoy `appointment_notice`) |
| `no_show` {on, offer_new} | si no llegó, ofrecer otro horario |

### 4.2 `appointment_type_hosts` (quién atiende)
`appointment_type_id`, `user_id` (con Google conectado) o `resource_id`, `catalog_item_ids` [] (qué servicios
hace; vacío = todos), `weight` (reparto), `active`.

### 4.3 `booking_schedules` (horario de cada persona o recurso)
Horario semanal por día (varios bloques: 9–14 y 16–20), excepciones por fecha (vacaciones, festivos, «este sábado
no»). Si una persona no tiene horario propio → el de la bandeja (como hoy).

### 4.4 `booking_resources` (opcional, etapa 4)
Cabina, sillón, consultorio, vehículo: algo que se ocupa durante la cita. Un tipo de cita puede necesitar uno.

### 4.5 `case_meetings` (ya existe) — se agrega
`appointment_type_id`, `booked_for` (nombre de para quién, «Laura, su esposa»), `source` (`agent` · `dali` ·
`agenda` · `public_page`), `tracking_template_id` (qué agente la agendó), `services` (los del Catálogo, con precio
y minutos al momento de agendar).

## 5. El motor

Un servicio que usan todos (agentes, Dali, Agenda, página pública):

```
Booking::Engine.new(account, appointment_type)
  .slots(from:, services: [], host: nil, for_whom: nil, limit: 3)   # horarios libres
  .book(start:, contact:, services:, host:, for_whom:, notes:, source:) # crea la cita (CaseMeeting + Google)
  .move(meeting, start:)
  .cancel(meeting, reason:)
```

- **Disponibilidad** = horario de la persona (o de la bandeja) − su Google ocupado − citas de Kontrolya − tiempos
  entre citas − anticipación − topes por día − excepciones; filtrada por quién hace esos servicios y por recursos.
  Se apoya en `AvailabilitySlotService` (se extiende, no se reescribe: lo usan también los agentes 1.0).
- **Duración**: fija o suma de servicios (+ tiempos entre citas).
- **Reparto**: el primero libre, por turnos o el que pidió.
- **Después de agendar**: evento de Google (ya con espera por la transacción: `MeetingSyncJob` espera el commit),
  recordatorio, «no llegó», nota y etiqueta (lo de cada agente sigue en su `Outcomes#booked`).
- **Reglas en un solo lugar**: lo que hoy está en `Skills::Appointments` + `AppointmentServices` + `AppointmentList`
  pasa al motor; la habilidad queda delgada: herramientas para el modelo, memoria y el texto de confirmación.

## 6. Pantallas

1. **Agenda › Tipos de cita** (nueva): lista y asistente por pasos — Qué es (nombre, duración o por servicios,
   modalidad, lugar) · Quién atiende (personas, qué servicios hace cada una, reparto) · Cuándo (horario, tiempos
   entre citas, anticipación, topes) · Antes y después (datos a pedir, política, recordatorio, no llegó) ·
   **Probar** (ver los horarios que ofrecería hoy).
2. **Agenda › Horarios del equipo** (nueva): horario semanal y excepciones de cada persona.
3. **Agentes listos** (prospectos, clientes) y **Campañas** (Ofrecer/Reactivar con meta «cita»): en lugar de sus
   campos de citas, un selector **«Qué citas agenda»** (uno o varios tipos) y «cuándo ofrecerla».
4. **Agenda** (calendario): crear cita eligiendo tipo → horarios del motor.
5. **Reportes › Citas** (etapa 5): por tipo, por persona, por agente; ocupación, «no llegó», canceladas.

## 7. Etapas

| Etapa | Qué | Resultado |
|---|---|---|
| **A1 — Tipos de cita** | tablas `appointment_types` + `appointment_type_hosts`; pantalla de tipos; motor con lo que hay hoy (duración fija o por servicios, personas, lugar, modalidad, recordatorio, política) | una estética configura «Cita en estética» una vez |
| **A2 — Agentes y campañas usan tipos** | selector «Qué citas agenda» en prospectos, clientes y campañas; **migración** de la configuración de hoy a un tipo por agente (sin cambiar cómo agendan); la habilidad llama al motor | los tres agentes agendan igual; se quitan los campos repetidos |
| **A3 — Reglas de agenda** | tiempos entre citas, anticipación mínima/máxima, tope por día, paso de horarios; quién hace qué servicio | «Mariana no hace uñas», «no con menos de 2 h» |
| **A4 — Horario por persona y recursos** | `booking_schedules` (semanal + excepciones); `booking_resources` (cabina, sillón) | Karla martes a sábado; una cabina no se empalma |
| **A5 — Fuera de los agentes** | Dali agenda con tipos; Agenda › nueva cita por tipo; **página pública de reservas** por tipo (liga para redes / WhatsApp) | reservas sin agente |
| **A6 — Reportes** | citas por tipo, persona y agente; ocupación; no llegó | saber qué funciona |

Cada etapa con sus pruebas (`spec/services/booking/…`), guía de Dali (`config/assistant/guides/agenda.md` y las de
agentes) y `Rails.application.eager_load!` antes del commit.

## 8. Migración de lo que ya existe (A2)

- Por cada agente con citas prendidas se crea un tipo «Citas de «nombre del agente»» con su configuración actual
  (personas, minutos, modalidad, lugar, citas de servicio, recordatorio) y se le asigna. Mismo comportamiento.
- Campañas con meta «cita»: un tipo por campaña viva, o el del agente si coincide.
- Los campos viejos (`appointment_user_ids`, `appointment_minutes`, `appointment_kind`, `appointment_location`,
  `appointment_services`, `sales.booking`, `appointment_notice`) se siguen leyendo hasta que todo esté migrado; luego
  se quitan del asistente.
- `tracking_templates.calendar_integration_ids` / `calendar_event_duration` **no se tocan** (los usan los agentes
  a medida 1.0).

## 9. Riesgos

- **Google free/busy**: más reglas = más consultas; cachear por persona y ventana (pocos minutos).
- **Zonas horarias**: tipo, persona y bandeja pueden estar en zonas distintas; todo en la zona del tipo (o de la
  cuenta) y se muestra al cliente en la suya.
- **Citas creadas en la transacción del turno** (ya visto el 2026-11-27): el motor encola Google después del commit.
- **No romper los agentes 1.0** que usan `AvailabilitySlotService`: extender con opciones nuevas, valores por omisión
  iguales a hoy.

## 10. Preguntas para el usuario (antes de A1)

1. ¿Página pública de reservas (A5) entra en este plan o va aparte?
2. ¿Anticipo / pago al agendar (liga de pago) se considera, o solo el texto de la política?
3. ¿Recursos (cabinas, sillones) se necesitan ya, o con personas basta por ahora?
4. Reparto: ¿«por turnos» debe contar citas del día o de la semana?
5. ¿El cliente puede **elegir con quién** en todos los tipos, o es opción de cada tipo?
