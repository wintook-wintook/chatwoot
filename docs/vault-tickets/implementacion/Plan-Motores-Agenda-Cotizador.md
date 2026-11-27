# Plan — Motores de la cuenta: agenda y cotizador

> Estado: 📝 **plan, sin empezar** (2026-11-27). Pedido por el usuario después de la demo de la estética:
> - «con el tema de agendar, ¿no deberíamos tener un motor especial para eso, ya que hay varias configuraciones?»;
> - «incluye el motor del cotizador: son dos cosas que deben tener una configuración global y cada agente apagar y
>   prender funcionalidades».
>
> Se hace **después de la demo**, en su propia rama. No toca «Agentes a medida» (1.0).

## 1. La idea en una línea

**Lo que hace la empresa se configura una vez en la cuenta; cada agente solo prende o apaga lo que usa.**

**Regla (usuario, 2026-11-27):** «Atención a clientes» (y los otros agentes) los usa **cualquier giro**. Nada del
negocio va en el código ni en las indicaciones a mano: lo que cambia de un giro a otro (qué preguntar antes de
cotizar, variantes, cómo se agenda) se **configura** en el motor de cotizar, en el de agenda o en la atención.

Hoy agendar y cotizar ya son piezas compartidas del motor 2.0 (`Skills::Appointments`, `Skills::Quote`), pero **cada
agente trae su propia configuración** de citas y de cotizaciones. Una empresa con agente de prospectos, de clientes y
campañas configura lo mismo tres veces y puede quedar distinto.

Dos motores de la cuenta, con el mismo patrón:

| | Configuración global (una vez) | En cada agente (prender / apagar) |
|---|---|---|
| **Agenda** | Tipos de cita: duración, quién atiende, horarios, reglas, recordatorio, política | «Agenda citas» sí/no · qué tipos · cuándo ofrecerla |
| **Cotizador** | Qué se cotiza, cómo se entrega, reglas de precio y descuento, la cuenta en el chat, vigencia, seguimiento, vendedor | «Cotiza» sí/no · «Arma la cuenta» sí/no · cómo la entrega (la de la cuenta o solo borrador) · qué parte del catálogo |

Y un tercer pieza común: **«Qué hace este agente»** — un panel con interruptores en cada agente (Agenda, Cotizar,
Armar la cuenta, Recomendar productos, Mandar archivos, Levantar casos…). Cada interruptor dice «se configura en …» y
lleva a la configuración global.

## 2. Cómo está hoy (lo que se junta)

### 2.1 Agenda
| Dónde | Qué se configura hoy | Código |
|---|---|---|
| Atención a prospectos › Al calificar | con quién, minutos, tipo (llamada/videollamada/visita/oficina), lugar, citas de servicio | `Functions::Prospects#appointments` |
| Atención a clientes › Comercial | demo / visita / citas de servicio (`booking`), personas, minutos | `Functions::Customers#appointments`, `CustomerAreas` |
| Atención a clientes › Soporte | visita técnica: personas, minutos | `Customers#technical_visit` |
| Vendedor de campaña (meta «cita») | personas, minutos; recordatorio de la campaña | `Functions::CampaignSeller`, `TrackingCampaigns::AppointmentReminder` |
| Los tres agentes › Seguimiento | recordatorio de la cita y plantilla | `Functions::Extras#appointment_notice`, `Motor2::AppointmentNotice` |
| La bandeja | horario de atención = horario de citas | `Inbox#working_hours` |
| Catálogo | duración de cada servicio | `catalog_items.duration_minutes` |

Piezas que ya existen: `ContactTrackings::AvailabilitySlotService` (Google free/busy, horario, reparto, recursos
`booking_calendars`), `CaseMeeting` + `AgendaItems::Creator` + `Cases::MeetingSyncJob`, y en la conversación
`AppointmentList` (varias citas, para otra persona), `AppointmentChanges`, `AppointmentServices`, `Motor2::SlotPick`.

### 2.2 Cotizador
| Dónde | Qué se configura hoy | Código |
|---|---|---|
| Los tres agentes › Cotizaciones | no cotiza / borrador / se la manda; preguntar a los N días; su plantilla; **armar la cuenta** | `Functions::Extras#quote_mode`, `QuoteMode.vue` |
| Atención a clientes › Comercial | cotización → oportunidad o al vendedor; tipo de caso | `CustomerAreas` (`sales.quote`, `case_type_id`) |
| Cada agente | a quién va (vendedor) = a quien lo pasa | `Skills::Quote#seller` |
| Campaña Ofrecer | precio de promoción y vigencia | `CampaignSeller#promo_price_for` |
| Ventas › Cotizaciones › Formatos | PDF, datos de la empresa, condiciones | `QuoteFormat`, `Quotes::FormatSettings`, `Quotes::Pdf` |
| Ventas | vigencia (`Quotes::Builder::VALID_DAYS`), versiones, oportunidad | `Quotes::Builder`, `Quotes::OpportunitySync` |
| Catálogo › Parámetros | impuesto por producto, «el precio ya incluye el impuesto», retenciones | `CatalogItemParameters` |
| Dali | cotizar desde el asistente | `Assistant::QuoteTools`, `Assistant::QuoteRunner` |

Piezas que ya existen: `Motor2::CartTotals` (las cuentas de «su cuenta»), `Skills::QuoteCart`, `Skills::Quote`
(arma, actualiza la misma, manda), `Quotes::Builder`, `Quotes::Delivery`, `Motor2::QuoteFollowUpJob`,
`Motor2::CatalogSearch#item`.

## 3. Lo que falta (por qué motores)

**Los dos:**
1. Configuración repetida en cada agente y en cada campaña.
2. Dali, la Agenda / Ventas a mano y una futura página pública deberían usar las **mismas reglas** que los agentes.
3. Reportes por agente: cuántas citas / cotizaciones salieron de cada uno y cuántas se ganaron.

**Agenda:** horario por persona; qué servicios hace cada quien; tiempo entre citas, anticipación, topes por día;
recursos (cabina, sillón); política por tipo; datos antes de agendar.

**Cotizador:**
1. **Qué se puede cotizar:** hoy el agente ve todo el catálogo de la cuenta (en la demo de la estética salían también
   «Mantenimiento A/C» y «Licencias Kontrolya»). Falta elegir categorías o productos por agente o por cotizador.
2. **Reglas de precio:** descuentos (nunca / hasta X % / por volumen), mínimo de compra, productos que siempre pasan
   por un vendedor, «cotizaciones de más de $X van en borrador».
3. **Cómo se entrega:** borrador o mandarla, formato (PDF), vigencia, condiciones — hoy la vigencia es fija en código.
4. **Vendedor:** hoy es «a quien lo pasa» el agente; falta dueño del contacto, por turnos o persona fija.
5. **La cuenta en el chat:** mostrar con IVA incluido o desglosado, máximo de partidas, si se ofrece siempre.
6. **Seguimiento:** días y plantilla, hoy por agente.
7. **Atributos por línea** (pedido del usuario, 2026-11-27): cada línea del catálogo tiene sus características —carnes:
   corte, presentación (kilo, paquete, caja), calidad; cortes de cabello: para (dama, caballero), largo; uñas: tipo,
   zona (manos, pies); aires: capacidad, tipo, voltaje—. Hoy no existen: el agente adivina la variante o pregunta
   opciones que no hay («gelish, acrílicas o pedicure spa»), y la cantidad no sabe si es kilos o piezas.
8. **Preguntas del pedido** (pedido del usuario): lo que **no es del producto** sino del cliente o del pedido y el
   agente debe saber antes de dar precio, cotizar o agendar: ciudad o zona (precio, envío o cobertura), fecha del
   evento, número de personas, si requiere factura, giro del cliente… Hoy solo existen los «datos obligatorios» de
   prospectos (nombre, correo, empresa, ciudad) y las preguntas de calificar; el agente de clientes no tiene dónde
   configurarlas. (Lo que es del producto —dama o caballero, kilo o paquete, calidad— va en los atributos por línea.)

## 4. Modelo

### 4.1 Agenda
- **`appointment_types`** (por cuenta): `name`, `description`, `active`, `color`; `duration_mode` (`fixed` ·
  `services`), `minutes`, `catalog_category_ids` / `catalog_item_ids`; `modality` (`in_person` · `call` · `video` ·
  `on_site`), `location`, `meeting_link_mode`; `assignment` (`any` · `round_robin` · `customer_choice`);
  `buffer_before`, `buffer_after`, `min_notice_minutes`, `max_days_ahead`, `max_per_day`, `slot_step_minutes`;
  `required_contact` []; `policy_text`; `reminder` {on, hours_before, template}; `no_show` {on, offer_new}.
- **`appointment_type_hosts`**: tipo × persona (o recurso), qué servicios hace, peso del reparto.
- **`booking_schedules`**: horario semanal por persona o recurso + excepciones (vacaciones, festivos).
- **`booking_resources`** (etapa A4): cabina, sillón, consultorio, vehículo.
- **`case_meetings`** (+): `appointment_type_id`, `booked_for`, `source` (`agent` · `dali` · `agenda` ·
  `public_page`), `tracking_template_id`, `services`.

### 4.2 Cotizador
- **`quoting_settings`** (una por cuenta; si un día hace falta, varias «listas de precios»):
  | Campo | Qué es |
  |---|---|
  | `catalog_category_ids` / `catalog_item_ids` | qué se cotiza (vacío = todo el catálogo activo) |
  | `delivery` | `draft` (el vendedor la revisa) · `send` (se la manda) |
  | `draft_over_amount` | arriba de este total, siempre en borrador |
  | `always_seller_item_ids` | productos que siempre pasan por un vendedor |
  | `discounts` | `none` · `max_percent` · `volume` [{min_qty, percent}] |
  | `min_amount` | mínimo para cotizar |
  | `valid_days` | vigencia (hoy `Quotes::Builder::VALID_DAYS`) |
  | `quote_format_id` | formato / PDF |
  | `seller_mode` | `contact_owner` · `round_robin` · `fixed` (+ `seller_user_ids`) · `agent_handoff` (como hoy) |
  | `opportunity` {create, case_type_id, stage} | la oportunidad que se crea |
  | `cart` {on, show_tax: `included` · `breakdown` · `by_product`, max_items, offer: `always` · `once`} | «su cuenta» en el chat |
  | `follow_up` {on, days, template} | preguntarle por la cotización |
  | `before_quote` [] | **preguntas antes de cotizar** (ver abajo) |

- **`before_quote`** — cada pregunta:
  | Campo | Qué es |
  |---|---|
  | `ask` | la pregunta («¿Es para dama o caballero?», «¿En qué ciudad?», «¿Para cuántas personas?») |
  | `key`, `save_to` | dónde se guarda: dato del contacto, atributo personalizado o solo en la plática |
  | `values` [] | opciones válidas (dama / caballero), si las hay |
  | `applies_to` | a qué productos o categorías aplica (solo «Cortes»; todo el catálogo) |
  | `use` | `filter` (elige la variante: dama → «Corte de dama») · `price` (cambia el precio: largo → +$400, ciudad → lista) · `info` (solo para el vendedor) |
  | `required` | sin esto no da precio ni cotiza / solo lo pregunta si no lo sabe |
  | `when` | antes de dar precio · antes de cotizar · antes de agendar |
  El agente la hace una sola vez (si ya lo sabe por la plática o el contacto, no pregunta), y el código no deja cotizar
  ni agendar ese producto sin la respuesta (como hoy `missing_contact`). Con `filter`, el producto lo elige el código
  con la respuesta, no el modelo. Se puede **probar** en la pantalla del cotizador.
- **`quotes`** (+): `source` (`agent` · `dali` · `ventas` · `public_page`), `tracking_template_id`.

### 4.2b Atributos por línea (Catálogo)
- **`catalog_attributes`**: `catalog_category_id` (la línea; las subcategorías heredan), `name` («Presentación»),
  `values` [] («kilo», «paquete 500 g», «caja»), `ask` («¿La quieres por kilo o en paquete?»), `position`,
  `required_to_quote` (sin ese valor no cotiza).
- **`catalog_items.attribute_values`** (jsonb) `{ attribute_id => valor }`: «Arrachera Prime kilo» = { Corte: arrachera,
  Calidad: Prime, Presentación: kilo }.
- **Productos separados con atributos** (recomendado, decisión pendiente §10): cada combinación es un producto con su
  precio y su unidad (no un producto con tabla de variantes). Ya funciona con cotizaciones e inventario; la búsqueda
  guiada los agrupa por línea.
- Formulario del producto: los atributos de su línea con sus valores; importación/exportación CSV con una columna por
  atributo.

**Búsqueda guiada** (`Quoting::Engine#find` / la usan cotizar, «su cuenta», citas de servicio, Dali y la página
pública):
1. «quiero arrachera» → candidatos del catálogo (dentro de lo que se cotiza).
2. Si hay más de uno, el código ve **qué atributo los distingue** y pregunta solo ese, con los valores que existen
   entre los candidatos («¿Prime o Choice?»). Nunca ofrece valores que no hay.
3. Cada respuesta descarta; con uno solo, ya no pregunta. Lo que ya dijo o ya se sabe (del contacto o la plática) no
   se vuelve a preguntar.
4. La cantidad se pide en la unidad del producto (`catalog_units`): «¿cuántos kilos?», «¿cuántas piezas?».
Reemplaza las reglas provisionales de 2026-11-27 (`CatalogSearch#ambiguous_in`, `unclear_service`: «¿dama o
caballero?» por el nombre).

### 4.3 Qué hace cada agente — `motor2['capabilities']`
En la ficha del agente (sin tabla nueva):
```
capabilities: {
  appointments: { on: true, type_ids: [3, 5], when: 'quiere agendar un servicio' },
  quote:        { on: true, cart: true, delivery: 'account' | 'draft', category_ids: [] },   # [] = lo del cotizador
  recommend:    { on: true }, files: { on: true }, tickets: { on: false }, …
}
```
Cada función (`Prospects`, `Customers`, `CampaignSeller`) arma sus `skills` desde aquí en lugar de sus campos propios.
Un agente **solo puede restringir** lo global (menos categorías, borrador en vez de mandar), nunca ampliarlo.

## 5. Los motores

### 5.1 `Booking::Engine`
```
Booking::Engine.new(account, appointment_type)
  .slots(from:, services: [], host: nil, limit: 3)
  .book(start:, contact:, services:, host:, for_whom:, notes:, source:)
  .move(meeting, start:) / .cancel(meeting, reason:)
```
Disponibilidad = horario de la persona (o de la bandeja) − Google ocupado − citas de Kontrolya − tiempos entre citas −
anticipación − topes − excepciones; filtrada por quién hace esos servicios y por recursos. Extiende
`AvailabilitySlotService` (lo usan también los agentes 1.0: mismos valores por omisión). Encola Google después del
commit. Lo de la conversación (`AppointmentList`, `SlotPick`, confirmación) se queda en la habilidad, que llama al motor.

### 5.2 `Quoting::Engine`
```
Quoting::Engine.new(account, settings, limits: agent_capability)
  .find(name)                                  # producto permitido (CatalogSearch#item dentro de lo que se cotiza)
  .cart(items).totals                          # CartTotals con descuentos y reglas
  .quote(contact:, items:, existing: nil, source:)   # arma o actualiza la misma (Builder), con vendedor y vigencia
  .deliver(quote, conversation:)               # borrador o mandar (reglas: draft_over_amount, always_seller)
```
Reglas en un solo lugar: qué se puede cotizar, descuentos, mínimos, cuándo va en borrador, vendedor, vigencia,
seguimiento. `Skills::Quote` / `QuoteCart` quedan como la parte de la plática; Dali (`Assistant::QuoteTools`) y la
página pública usan el mismo motor.

## 6. Pantallas

1. **Agenda › Tipos de cita** y **Agenda › Horarios del equipo** (nuevas).
2. **Ventas › Cotizador** (nueva): Qué se cotiza · Cómo se entrega · Precios y descuentos · La cuenta en el chat ·
   Vendedor y oportunidad · Seguimiento · **Probar** (arma una cuenta y una cotización de ejemplo con estas reglas).
3. **En cada agente (Agentes listos y campañas): pestaña «Qué hace»** con interruptores. Cada uno con un resumen de lo
   global y «Cambiar en Agenda / en Cotizador»; si el agente restringe algo (menos categorías, solo borrador), se ve
   ahí. Se quitan las pestañas «Cotizaciones» y los campos de citas de cada asistente.
4. **Reportes** (al final): citas por tipo / persona / agente; cotizaciones por agente, ganadas, monto.

## 7. Etapas

| Etapa | Qué | Resultado |
|---|---|---|
| **M0 — «Qué hace» del agente** | `motor2['capabilities']`; pestaña con interruptores en los tres agentes; por ahora cada interruptor lleva a lo que hay hoy | el mismo lugar para prender y apagar en todos los agentes |
| **Q1 — Cotizador global** | `quoting_settings` + pantalla; `Quoting::Engine` con lo que hay hoy (modo, cuenta, seguimiento, vigencia, formato, vendedor); migrar lo de cada agente | se configura una vez; los agentes solo prenden «Cotiza» / «Arma la cuenta» |
| **Q2 — Qué se cotiza y reglas** | categorías/productos, productos que van con vendedor, borrador arriba de $X, mínimo, descuentos | el agente de la estética no ve «A/C»; reglas de negocio |
| **Q3a — Atributos por línea** | `catalog_attributes` + valores en cada producto (formulario y CSV); búsqueda guiada: pregunta solo lo que distingue y la cantidad en su unidad | «¿Prime o Choice?», «¿dama o caballero?», «¿cuántos kilos?» sale del catálogo, para cualquier giro |
| **Q3b — Preguntas del pedido** | `before_quote`: datos del cliente o del pedido (ciudad o zona, fecha del evento, personas, factura); obligatorias o no, si cambian el precio, dónde se guardan | «¿En qué ciudad?» configurado en el cotizador |
| **A1 — Tipos de cita** | `appointment_types` + `hosts`; `Booking::Engine` con lo que hay hoy | «Cita en estética» se configura una vez |
| **A2 — Agentes y campañas usan tipos** | interruptor «Agenda citas» con sus tipos; migrar la configuración de cada agente | los tres agendan igual |
| **A3 — Reglas de agenda** | tiempos entre citas, anticipación, topes, paso de horarios, quién hace qué servicio | «Mariana no hace uñas» |
| **A4 — Horario por persona y recursos** | `booking_schedules`, `booking_resources` | Karla martes a sábado; la cabina no se empalma |
| **M5 — Fuera de los agentes** | Dali, Agenda y Ventas a mano con los motores; **página pública** (catálogo + cuenta + agendar) | reservar y cotizar sin agente |
| **M6 — Reportes** | citas y cotizaciones por agente, tipo y persona | saber qué funciona |

Orden sugerido: **M0 → Q3a → Q1 → Q2 → Q3b → A1 → A2 → A3 → A4 → M5 → M6**: con atributos el agente pregunta bien
desde el principio; el cotizador es más chico y ya tiene casi todo; la agenda trae tablas nuevas. Cada etapa con sus pruebas, guía de Dali y `Rails.application.eager_load!` antes del commit.

## 8. Migración de lo que ya existe

- **Cotizador:** la configuración más común de los agentes de la cuenta pasa a `quoting_settings`; si un agente era más
  restrictivo (borrador en vez de mandar), queda como restricción en su interruptor. Mismo comportamiento.
- **Agenda:** por cada agente con citas se crea un tipo «Citas de «agente»» con lo que tenía y se le asigna; campañas
  con meta «cita», el tipo del agente o uno propio.
- Los campos viejos (`quote`, `appointment_user_ids`, `appointment_minutes`, `appointment_kind`, `appointment_location`,
  `appointment_services`, `sales.booking`, `appointment_notice`) se siguen leyendo hasta que todo esté migrado; luego se
  quitan de los asistentes.
- `tracking_templates.calendar_integration_ids` / `calendar_event_duration` **no se tocan** (agentes a medida 1.0).

## 9. Riesgos

- **Google free/busy:** más reglas = más consultas; cache corto por persona y ventana.
- **Zonas horarias:** todo en la zona del tipo de cita (o de la cuenta).
- **Transacción del turno** (visto el 2026-11-27): los motores encolan Google y la entrega de la cotización después del
  commit.
- **No romper 1.0:** `AvailabilitySlotService` se extiende con opciones nuevas, valores por omisión iguales a hoy.
- **Totales:** un solo cálculo (`CartTotals` + `QuoteItem#tax_amount`) para la cuenta del chat, la cotización y el PDF.

## 10. Preguntas para el usuario (antes de empezar)

1. ¿La página pública (reservar y cotizar sin agente) entra en este plan o va aparte?
2. ¿Anticipo / pago al agendar o al aceptar la cotización (liga de pago), o solo el texto de la política?
3. ¿Recursos (cabinas, sillones) ya, o con personas basta por ahora?
4. Cotizador: ¿una sola configuración por cuenta, o varias «listas de precios» (mayoreo / menudeo, por sucursal)?
5. Descuentos: ¿los agentes pueden darlos según reglas, o nunca (como hoy) y solo el vendedor?
6. Vendedor de la cotización: ¿dueño del contacto, por turnos o persona fija como opción por omisión?
7. ¿El cliente puede pedir con quién en todos los tipos de cita, o es opción de cada tipo?
8. Preguntas del pedido: ¿van en el cotizador (para todos los agentes) y cada agente solo las prende, o cada agente
   puede agregar las suyas?
9. Variantes: ¿productos separados con atributos (recomendado) o un producto con tabla de variantes y precios?
