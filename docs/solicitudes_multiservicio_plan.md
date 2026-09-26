# Plan — Pieza 5: `@solicitudes` (varios servicios en una conversación)

> Plan (26/09/2026). Sigue a `docs/hoja_buscar_plan.md` (piezas 1–4) y al diseño del agente
> de Grúas (`docs/agente_gruas_ssusa_rutas.md`). Decisiones cerradas el 26/09 (§11).

---

## 0. El problema, medido

Ejemplos del corpus que hoy no se pueden resolver:

| Ej. | Cliente | Pide en UN mensaje |
|---|---|---|
| 6 | Blue Marine | grúa 60 t + tracto con plana 12 m + camión con hiab (y al otro día 2 hiab + 1 hiab + 1 grúa) |
| 10 | MADISA | 2 fletes de maquinaria «por separado» + horas de hiab |
| 11 | Expro | «SOLICITUD 01», «SOLICITUD 02»… cada una con origen, destino, fecha y hora |
| 3 | Cotemar | 2 HIAB distintos (14–15 t y 12 t) |
| 19 | ARBAMEX | «entrega y recolección» = 2 movimientos separados en el tiempo |
| 14 / 25 | Baker Hughes | viaje redondo / «consolidar» 2 tramos = UN servicio con varias paradas |
| 16 | OPEX | 2 cargas en un mismo servicio; una medida corregida en el hilo |

Hoy el motor tiene **una** cita por conversación y **un** caso abierto por contacto:

```
conversación ──► seguimiento (ContactTracking)
                   ├─ appointment_event_id / appointment_at / appointment_status   ← UNA cita
                   └─ @crear_ticket → si ya hay un caso abierto, lo REUSA          ← UN caso
```

- El segundo servicio se pega al caso abierto (`TicketCreatorService#reuse_existing_ticket`).
- La segunda cita choca con «ya tienes una cita» (`inform_existing_appointment`).

---

## 1. La idea: cada servicio es un CASO con su TAREA AGENDADA

No se inventa una tabla nueva. El módulo de Tickets ya tiene lo que hace falta:

| Hace falta | Ya existe en Tickets |
|---|---|
| Un registro por servicio, con sus datos | `CaseTicket` (tipo de caso, campos propios `custom_attributes`, folio, `contact_tracking_id`) |
| Su horario en el calendario del equipo | `CaseMeeting` = **Tarea agendada** (inicio, fin, `google_calendar_id`, espejo en Google, mover, cancelar, recordatorios) |
| Que el equipo lo vea y lo mueva | Kanban de Tickets, columnas por tipo |

```
conversación ─► seguimiento
                   │  @solicitudes
                   ▼
   ┌──────────────── Servicio 1 ─────────────────┐  ┌──────────── Servicio 2 ────────────┐
   │ CASO #00123 «Solicitud de transporte»        │  │ CASO #00124                        │
   │  equipo: grúa ≥ 60 t   origen: km 14+500     │  │  equipo: hiab 10–12 t  …           │
   │  destino: Blue Giant   folio: —              │  │                                    │
   │  └─ TAREA AGENDADA  29 may 08:00–09:00       │  │  └─ TAREA AGENDADA 31 may 07:00…   │
   │       calendario GR-60 · [TENTATIVO]         │  │       calendario HB-12 · tentativo │
   └──────────────────────────────────────────────┘  └────────────────────────────────────┘
```

Los agentes **sin** `@solicitudes` siguen exactamente igual (una cita en el seguimiento).

---

## 2. La directiva

```
@ruta(solicitud_servicio #solicita_servicio: solicito programar, favor de programar las siguientes unidades, SOLICITUD 01, …):
    {{hoja:Equipos}}
    -> @solicitudes
    -> @crear_ticket(tipo=Solicitud de transporte)
    -> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
    -> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}}
```

`@solicitudes` cambia el significado de lo que sigue: **cada** acción se hace **por servicio**.
Sin `@solicitudes`, las mismas directivas hacen lo de hoy.

---

## 3. Separar el mensaje en servicios (IA con esquema fijo)

Una llamada a la IA con salida JSON validada (como el extractor de fechas):

```json
{ "servicios": [
  { "ref": "1", "etiqueta": "Grúa 60 t",
    "equipo": { "tipo": "grúa", "capacidad_t": 60 },
    "paradas": [ { "tipo": "origen",  "lugar": "Patio Pemex km 14+500" },
                 { "tipo": "destino", "lugar": "Patio Blue Giant (API)" } ],
    "fecha": "2026-05-29", "hora": "08:00", "duracion_min": 60,
    "carga": "materiales Pemex", "peso_t": null, "medidas": null,
    "folios": ["NAV19602808"], "responsable_sitio": null,
    "modalidad": "On Call", "notas": "datos de personal para accesos Pemex" }
] }
```

Reglas del extractor (en su prompt, probadas con el corpus):

| Regla | Ejemplo |
|---|---|
| Un servicio por equipo o por «SOLICITUD 0N» | ej. 6, 11 |
| «por separado» = servicios distintos | ej. 10 |
| «consolidar» / «viaje redondo» = UN servicio con varias paradas | ej. 14, 25 |
| «entrega y recolección» = DOS servicios | ej. 19 |
| «presentarse en» = origen · «entregar en» = destino | ej. 8, 9 |
| Si un dato se corrige en el hilo, vale el último | ej. 16 (2 m → 10 m) |
| Sin fecha → servicio sin agenda (solo caso) | ej. 17, 21, 22 |

Lo que la IA **no** decide: fechas relativas y duraciones — las resuelve Ruby con lo que ya
existe (`AmbiguousDate`, `CalendarOptions.duration_in`, `calculate_reschedule_datetime`).

### 3.1 Duplicados y reiteraciones

Antes de crear, cada servicio se compara contra los **abiertos** de la misma conversación:

```
mismo tipo de equipo + misma fecha + mismo origen   →  es el mismo: se ACTUALIZA (último dato gana)
distinto                                            →  servicio nuevo
```
Ej. 6: «solicito nuevamente el servicio… de la plana y grúa» no abre casos repetidos.

---

## 4. La conversación

Una sola respuesta con todos los servicios, numerados:

```
👤 Solicito disponibilidad para mañana 29 de mayo 08:00, patio km 14+500 → Blue Giant:
   1 grúa cap. 60 tons, 01 tracto con plana de 12 mts, 01 camión con grúa tipo hiab

🤖 Recibí 3 servicios:
   1️⃣ Grúa 60 t — vie 29 may:   1A 08:00 ✅ libre (GR-60)
   2️⃣ Plana 12 m — vie 29 may:  2A 08:00 ✅ libre (TP-37)
   3️⃣ Hiab — 08:00 ocupado:     3A 09:00 · 3B 10:00 · 3C 11:00
   Responde con los que quieres apartar (por ejemplo «1A, 2A y 3B»), o «sí» para 1A, 2A y 3A.
```

- **Hora exacta libre** → se OFRECE como opción para confirmar (decisión 2): «1A 08:00 ✅ libre».
  No se aparta nada hasta que el cliente elige.
- **Ocupado o sin hora** → alternativas con código **número + letra** (3A, 3B…): un «1» suelto ya
  no alcanza con varios servicios.
- **«Sí» / «apártalos»** → la primera opción de cada servicio; «1A y 3B» → esas.
- **Faltan datos** → UNA pregunta para todos: «Del 2 me falta el peso; del 3, el destino».
- **«El día lunes»** sin número → la fecha completa, como en la pieza 6.

Estado de espera: hoy es un bloque `[PENDING_SLOT]` en `ai_context` (una oferta por
conversación). Con servicios, cada caso guarda **su** oferta (`metadata.offered_slots`) y la
elección «3B» se resuelve por el número del servicio.

---

## 5. Confirmar, mover y cancelar POR servicio

| Cliente | Qué hace |
|---|---|
| «Le confirmamos los servicios» / «confirmo todos» | `@confirmar_servicio` sobre todos los apartados |
| «Confirmo el 1 y el 3» | solo esos |
| «Cancela el hiab del muelle 13» | la IA elige el servicio de la lista (con su etiqueta); se cancela la tarea agendada y el caso |
| «El de la plana pásalo a las 10» | mover solo ese |
| «Vamos a reprogramar la entrega» (uno solo abierto) | ese |

Con varios abiertos y sin decir cuál → «¿Cuál? 1️⃣ Grúa 60 t · 2️⃣ Plana 12 m · 3️⃣ Hiab».

**Pago** (`@confirmar_servicio(requiere=pago)`, decisión 3):
- etiqueta `pago_confirmado` en la conversación → **todos** los servicios esperando pago quedan en
  firme (un pago por el paquete, lo común);
- caso movido a la columna **«Pagado»** del Kanban (tipo «Solicitud de transporte») → **solo ese**
  servicio queda en firme (pago parcial). Se engancha al cambio de `case_type_column_id`.
Las dos avisan al cliente: «✅ Recibimos tu pago. Tu servicio N del … quedó confirmado».

---

## 6. Qué cambia en el motor

```
ContactTrackingResponseAnalyzerJob
  └─ ruta con @solicitudes ──► ContactTrackings::ServiceRequests (nuevo)
                                 ├─ Extractor      (IA → servicios, §3)
                                 ├─ Matcher        (duplicados, §3.1)
                                 ├─ por servicio:
                                 │    Cases::TicketCreatorService (sin reusar: 1 caso por servicio)
                                 │    SheetLookup / SheetCalendars (calendario de SU equipo)
                                 │    AvailabilitySlotService (su duración, 24 h)
                                 │    CaseMeeting (tarea agendada, tentativa)  ← en vez de
                                 │                  appointment_* del seguimiento
                                 └─ Reply          (un mensaje con todos, §4)
```

| Pieza de hoy | Cambio |
|---|---|
| `TicketCreatorService#reuse_existing_ticket` | con `@solicitudes`, no reusa: busca por servicio (§3.1) |
| `handle_book_appointment` / `[PENDING_SLOT]` | por servicio, oferta en el caso |
| `ServiceConfirmation` (pieza 4) | trabaja sobre la tarea agendada del caso |
| `ServiceConfirmationListener` | confirma todas las tareas en espera de pago de la conversación |
| `CaseMeeting` | + estado tentativo (`metadata.tentative` o columna); el espejo de Google ya existe |

---

## 7. Rentas de días o meses (ej. 18 y 25) — entra en esta pieza (decisión 5)

La agenda llega hoy a 24 h. Una renta de 6 meses **no** se ofrece por horarios: se ofrece un
**bloque de días completos** (tarea agendada de día completo, inicio–fin):

```
👤 Renta de grúa 90 t por 6 meses a partir del 1 de noviembre
🤖 1️⃣ Grúa 90 t — 1 nov 2026 → 30 abr 2027:  1A ✅ libre todo el periodo (GR-90)
```
- `duracion=?` acepta «6 meses», «3 semanas», «15 días», «renta mensual» (= 1 mes) → bloque.
- Disponible = sin ningún choque en todo el periodo (freeBusy del periodo completo; Google
  permite consultar rangos largos por partes).
- Si choca: «ocupada del 3 al 10 de diciembre» y la siguiente fecha en que el periodo completo
  cabe, o el mismo tipo de equipo que sí esté libre.
- Sin fecha de inicio → se pregunta.

---

## 8. Comprobador, catálogo y Asistente

- `@solicitudes` sin `@crear_ticket` después → rojo: «cada servicio necesita su caso».
- `@solicitudes` con tipo de caso sin los campos del servicio (origen, destino, fecha…) → ámbar.
- Ficha en Recursos del Asistente; `Directives.strip_tokens` la quita del texto al modelo.

---

## 9. Fases

| Fase | Qué | Tamaño |
|---|---|---|
| F0 | Estado tentativo en `CaseMeeting`; el espejo de Google con «[TENTATIVO]» y calendario del equipo | chico |
| F1 | Extractor de servicios (IA + esquema) con las reglas de §3, probado contra los 26 ejemplos (sin conversación) | mediano |
| F2 | `@solicitudes` + un caso por servicio + duplicados/reiteraciones | mediano |
| F3 | Agenda por servicio: calendario de su equipo, su duración, apartar si está libre, ofertas «3A/3B» | grande |
| F4 | Confirmar / mover / cancelar por servicio; pago de todos con la etiqueta | mediano |
| F5 | Comprobador, catálogo, Asistente, i18n | chico |
| F6 | Pila de pruebas (§10) + bitácora en los dos .md | chico |
| F7 | Rentas de días/meses (bloques de días completos, §7) | mediano |

---

## 10. Pila de pruebas prevista

En *Agents IA Test* con la copia #10368, calendarios de prueba (agenda 178). Con las hojas
«Equipos» y «Unidades» si ya existen; si no, con los 24 remolques.

| # | Mensaje (del corpus) | Esperado |
|---|---|---|
| P1 | Ej. 11: SOLICITUD 01 pick up 11:00 + SOLICITUD 02 (agregada) 14:00 | 2 casos, 2 tareas tentativas, un mensaje con 1️⃣ y 2️⃣ |
| P2 | Ej. 6-A: grúa 60 t + plana 12 m + hiab, mañana 08:00 | 3 casos; libres apartados; ocupado con 3A/3B |
| P3 | Ej. 6-A repetido dos días después («solicito nuevamente») | 0 casos nuevos: se actualizan los 3 |
| P4 | Ej. 10: 2 fletes «por separado» 18:00–00:00 | 2 casos, 6 h cada uno, horario 24 h |
| P5 | Ej. 25: «consolidar» NAV…150 + NAV…449 | 1 caso con 2 paradas y 2 folios |
| P6 | Ej. 19: «entrega y recolección» | 2 casos (entrega / recolección) |
| P7 | P2 + «confirmo el 1 y el 3» | solo 1 y 3 en firme (o pago pedido) |
| P8 | P2 + «cancela el hiab» | solo el 3 cancelado (caso y tarea) |
| P9 | P2 + etiqueta `pago_confirmado` | todos los que esperaban pago, en firme |
| P10 | Ej. 7 (un solo servicio) con agente SIN `@solicitudes` | igual que hoy (una cita) |
| P11 | Ej. 18: renta 6 meses de grúa 90 t desde el 1 de noviembre | bloque ofrecido con fechas completas |
| P12 | P2 + mover solo el caso 2 a la columna «Pagado» | solo el 2 en firme |

---

## 11. Decisiones (26/09/2026)

1. **Servicio = caso + tarea agendada.** ✅
2. **Hora exacta libre → se OFRECE como opción** para que el cliente la confirme (no se aparta directo). ✅
3. **Pago: las dos.** Etiqueta `pago_confirmado` = todos los servicios en espera de pago; columna
   «Pagado» del Kanban = solo ese caso (pago parcial). ✅ (recomendación aceptada: «lo mejor»)
4. **Un solo tipo de caso: «Solicitud de transporte».** ✅ (con su columna «Pagado»)
5. **Rentas de días/meses entran en esta pieza** (F7, §7). ✅

---

## 12. Cómo se le pedirá al Asistente (cuando esté hecho)

```
En la ruta solicitud_servicio, después de la flecha y en este orden exacto:
@solicitudes -> @crear_ticket(tipo=Solicitud de transporte) -> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
-> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}}
Frases: solicito programar, favor de programar las siguientes unidades, SOLICITUD 01, requerimos
las siguientes unidades, programa de embarque.
```
Luego «Analiza el prompt». (Se confirmará con la pila de pruebas en F6.)

---

## 13. Bitácora por fase

### F0 — Tarea agendada tentativa en el calendario del equipo (26/09/2026) ✅

**Qué se hizo.** `case_meetings.tentative` (migración `20260926140000`) y
`ContactTrackings::ServiceMeeting`: `hold!` crea la Tarea agendada del caso con «[TENTATIVO] …»
y su evento DIRECTO en el calendario del equipo (sin Meet ni invitaciones — el espejo de
Tickets sí los manda); `confirm!` quita «[TENTATIVO]» del evento y de la tarea; `cancel!` usa el
espejo de siempre. Mover y cancelar desde Tickets siguen funcionando con el mismo evento.

**Pruebas.** `service_meeting_spec` (3): aparta sin Meet ni correos · si Google falla la tarea
queda marcada · confirmar quita «[TENTATIVO]». En vivo: con F3.

**Cómo pedírselo al Asistente.** No aplica todavía (pieza interna).

### F1 — Separar un mensaje en servicios (26/09/2026) ✅

**Qué se hizo.** `ContactTrackings::ServiceRequests::Extractor`: una llamada a la IA (gpt-4o como
mínimo, `EngineConfig` `:service_requests`) con las reglas de §3; fechas, horas y duraciones se
devuelven como las escribió el cliente. «Entrega y recolección» de ida y vuelta se parte en dos
sin IA (la IA insistía en un viaje redondo).

**Pila de pruebas (corpus, sin conversación).** 12 ejemplos, medido el 26/09:

| Ejemplo | Esperado | 1ª vuelta | Final |
|---|---|---|---|
| 3 · 2 hiab distintos | 2 | ✅ 2 | ✅ 2 |
| 6A · grúa + plana + hiab | 3 | ✅ 3 (fecha mezclada con la hora) | ✅ 3 (fecha «29 de mayo 2026», hora «08:00 am») |
| 6B · programa (02 hiab + 1 hiab + grúa) | 4 | ❌ 3 (juntó los 2 hiab) | ✅ 4 |
| 10 · 2 fletes «por separado» + horas de hiab | 3 | ✅ 3 (sin etiquetas) | ✅ 3, hora 6:00 pm + duración «6:00 pm - 12:00 am» |
| 11 · SOLICITUD 01 | 1 | ✅ 1 + folio DMX | ✅ |
| 14 · viaje redondo, 2 NAV | 1 | ✅ 1, 3 paradas, 2 folios | ✅ |
| 16 · magneto + «adicionalmente» 3 tramos | 1 | ❌ 2 | ✅ 1 |
| 19 · entrega y recolección | 2 | ❌ 1 | ✅ 2 (a veces 3: cuenta la renta del rack como servicio) |
| 25 · consolidar 2 tramos | 1 | ✅ 1, 3 paradas, 2 folios | ✅ |
| 7 · una plana | 1 | ✅ | ✅ |
| 18 · renta 4 equipos 6 meses | 4 | ✅ | ✅ |
| saludo | 0 | ✅ | ✅ |

Resultado: **9/12 → 12/12** (el 19 varía entre 2 y 3 según la IA). Spec: `extractor_spec` (4).

**Cómo pedírselo al Asistente.** No aplica todavía (se usa con `@solicitudes`, F2).

### F2 — `@solicitudes`: un caso por servicio (26/09/2026) ✅

**Qué se hizo.** `@solicitudes` en una ruta: el mensaje se separa en servicios (F1) y cada uno
es un caso (`CaseTicket`) de la conversación, con sus datos en `metadata['servicio']`, tipo y
prioridad del `@crear_ticket(...)` de la ruta y las reglas de Tickets aplicadas.
`DateResolver` vuelve fecha y hora lo que escribió el cliente, sin IA («29 de mayo 2026»,
«03 DE AGOSTO», «01-JUN-26», «30/06/2026», «mañana», «el día lunes» → ambiguo). Reiteraciones: un
servicio igual (tipo de equipo + fecha + origen) a uno abierto de un mensaje ANTERIOR lo
actualiza (último dato gana); dentro del mismo mensaje «02 camiones» siguen siendo dos.

**Cómo funciona.**
```
👤 …29 de mayo 2027 a las 08:00… UNIDADES REQUERIDAS 1 grúa cap. 60 tons, 01 tracto con plana de 12 mts, 01 camión con grúa tipo hiab
🤖 Recibí 3 servicios:
   1️⃣ Grúa 60 t · patio del km 14+500 → Blue Giant · sáb 29 may 08:00 (caso 01068)
   2️⃣ Plana 12 m · …                                                   (caso 01069)
   3️⃣ Hiab · …                                                         (caso 01070)
```

**Pruebas (Agents IA Test, copia #10368).**
| Conv | Mensaje | Resultado |
|---|---|---|
| 256 | ej. 6A (grúa + plana + hiab) | 3 casos ✅ |
| 256 | «Solicito nuevamente…» (mismo servicio) | grúa y plana actualizadas; el hiab se duplicó ❌ («camión con grúa tipo hiab» se leyó como grúa) → arreglado |
| 258 | ej. 6A + «solicito nuevamente» (después del arreglo) | «Actualicé 3 servicios que ya tenía» — mismos casos ✅ |
| 257 | ej. 10 (2 fletes por separado + horas de hiab) | 3 casos; «del 3️⃣ me falta la fecha y dónde es» ✅ |

Specs: `registry_spec` (5), `turn_spec` (2).

**Cómo pedírselo al Asistente.**
```
En la ruta solicitud_servicio, después de la flecha y en este orden exacto:
@solicitudes -> @crear_ticket(tipo=Solicitud de transporte, prioridad=media)
Frases: solicito programar unidades, favor de programar las siguientes unidades, unidades
requeridas, SOLICITUD 01, solicito cotizar un flete.
```

### F3 — Horarios por servicio y apartado en el calendario de cada equipo (26/09/2026) ✅

**Qué se hizo.** Con `@agendar_calendar(...)` y `{{hoja_buscar:}}` en la misma ruta, cada servicio
con fecha recibe hasta 3 opciones (1A, 1B, 1C) de los calendarios de SU equipo — la hoja se busca
con el texto del servicio («plana 40 t»), no con toda la conversación (`SheetLookup text:`). La hora
pedida, si está libre, es la opción A: se OFRECE (decisión 2). «1A y 2B» o «sí» aparta cada una como
Tarea agendada «[TENTATIVO]» en el calendario del equipo (`Choice` + `ServiceMeeting`). El extractor
ahora devuelve el tipo de equipo en una palabra (grúa, hiab, plana, cama baja…).

**Cómo funciona (conversación 259).**
```
👤 Solicito programar para el lunes 5 de octubre 2026 a las 09:00, del patio Carmen a Dos Bocas:
   01 plana de 40 toneladas, 01 cama baja para 30 t y 01 grúa de 60 t. El servicio dura 3 horas.
🤖 Recibí 3 servicios:
   1️⃣ Plana 40 t · patio Carmen → Dos Bocas · lun 5 oct 09:00 (caso 01078)
       1A 09:00–12:00 (TP-111) · 1B 09:00–12:00 (TP-82) · 1C 10:00–13:00 (TP-98)
   2️⃣ Cama baja 30 t · … (caso 01079)
       2A 09:00–12:00 (TP-46) · 2B 09:00–12:00 (TP-73) · 2C 10:00–13:00 (TP-74)
   3️⃣ Grúa 60 t · … (caso 01080)
       no tengo ese equipo en el catálogo
   Responde con los horarios que quieres apartar (por ejemplo «1A y 3B»), o «sí» para la primera opción de cada uno.
👤 1A y 2B
🤖 📌 Aparté:
   1️⃣ Plana 40 t · lun 5 oct 09:00–12:00 (TP-111)
   2️⃣ Cama baja 30 t · lun 5 oct 09:00–12:00 (TP-73)
   Quedan pendientes de confirmar: cuando me confirmes el servicio, los dejo en firme.
```
Resultado en la base: 2 Tareas agendadas «[TENTATIVO] …» 09:00–12:00, `synced`, en los calendarios de
la TP-111 y la TP-73 (agenda 178, de prueba).

**Pruebas.** Conversación 259 ✅ (arriba). Specs: `scheduler_spec` (3), `choice_spec` (4).

**Cómo pedírselo al Asistente.**
```
En la ruta solicitud_servicio, después de la flecha y en este orden exacto:
@solicitudes -> @crear_ticket(tipo=Solicitud de transporte, prioridad=media)
-> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
-> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}}
```
(Con la hoja actual de remolques: `{{hoja_buscar: Servicio Gruas | tipo=?; peso_max_t>=? | Calendar_ID}}`.)

### F4 — Confirmar, cancelar y mover POR servicio; pago (26/09/2026) ✅

**Qué se hizo.** `ServiceRequests::Actions`: el cliente se refiere a un servicio por número («el 1 y
el 3», «2️⃣») o por equipo («el hiab», «la plana»).
- **Confirmar** (mensaje en la ruta con `@confirmar_servicio`): sin decir cuál → todos los
  apartados. Con `(requiere=pago)` quedan «esperando pago» + nota al equipo.
- **Cancelar** («cancela», «anula», «ya no lo necesito»): tarea agendada y caso cancelados. Con
  varios abiertos y sin decir cuál → «¿Cuál quieres cancelar? 1️⃣ … 2️⃣ …».
- **Mover** («pásala / muévelo / reprograma» + fecha u hora; también «a las 11»): nuevas opciones
  (2A, 2B…); al elegir, la tarea anterior se cancela.
- **Pago** (`PaidService`): la etiqueta `pago_confirmado` deja en firme TODOS los que esperaban
  pago; mover un caso a la columna **«Pagado»** del Kanban deja en firme SOLO ese
  (`ServicePaidJob`, desde `CaseTicket` al cambiar de columna). El cliente recibe «✅ Recibimos tu
  pago. Tus servicios 1️⃣, 2️⃣ quedaron confirmados.»

**Pila de pruebas (conversación 259, continuación de F3).**
| Paso | Cliente / equipo | Resultado |
|---|---|---|
| 1 | «Cancela la grúa, ya no la necesitamos» | «Listo, cancelé: 3️⃣ Grúa 60 t (caso 01080)»; caso cancelled ✅ |
| 2 | «La cama baja pásala a las 11:00» | «2️⃣ Cama baja 30 t: 2A 05/10 11:00 (TP-46) · 2B … · 2C …» ✅ |
| 3 | «2A» | aparta 11:00–14:00 en TP-46; la tarea de las 09:00 queda cancelada (y su evento borrado) ✅ |
| 4 | «Le confirmamos los servicios» (ruta con `requiere=pago`) | pide el pago de 1️⃣ y 2️⃣ + nota; estado esperando_pago ✅ |
| 5 | etiqueta `pago_confirmado` | «✅ Recibimos tu pago. Tus servicios 1️⃣, 2️⃣ quedaron confirmados.»; tareas sin [TENTATIVO] ✅ |

Specs: `actions_spec` (5), `service_paid_job_spec` (2); `choice_spec` y `payment_confirmed_job_spec` siguen pasando.
Columna «Pagado»: probada con spec; en vivo requiere crear la columna en el tipo de caso.

**Cómo pedírselo al Asistente.**
```
Agrega la ruta confirmacion_servicio #confirmado con frases: le confirmamos el servicio, le
confirmamos los servicios, confirmo el 1, favor de presentarse mañana. Sin fuente, y después de
la flecha: @confirmar_servicio(requiere=pago)
```
Cancelar y mover no necesitan ruta propia: el motor los reconoce cuando hay servicios abiertos.
En Tickets → Tipos de caso → «Solicitud de transporte»: crear la columna **«Pagado»** para los
pagos parciales.

### F7 — Rentas de días o meses (26/09/2026) ✅

**Qué se hizo.** Si la duración del servicio es un periodo («6 meses», «3 semanas», «15 días»,
«renta mensual», «un año»; `CalendarOptions.period_days`), no se ofrecen horarios: se ofrecen los
equipos **libres todo el periodo** (`AvailabilitySlotService#free_for_period`). Google rechaza
consultas de más de 90 días (`timeRangeTooLong`, medido): se consulta en tramos de 60. Al elegir, la
Tarea agendada se aparta como evento de **días completos** del primero al último día.

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 260 | renta de low boy de 50 t por 3 meses a partir del 1 de diciembre 2026 | «1A 1 dic 2026 → 28 feb 2027 (TP-64)» (el único low boy ≥ 50 t libre los 3 meses) ✅ |
| 260 | «1A» | evento de día completo 1 dic → 1 mar en el calendario TP-64, «[TENTATIVO]» ✅ |

Specs: `period_days` (2), `free_for_period` por tramos (1), `hold!` de día completo (1), oferta de renta en `scheduler_spec` (1).

**Cómo pedírselo al Asistente.** Nada nuevo: la misma ruta de F3 con `duracion=?`; el cliente dice
«por 6 meses» / «renta mensual» y el motor lo trata como bloque.

### F5 — Comprobador y catálogo (26/09/2026) ✅

**Qué se hizo.**
- 🔴 `solicitudes_without_ticket`: `@solicitudes` sin `@crear_ticket` después.
- 🟡 `solicitudes_without_lookup`: `@solicitudes` con agenda pero sin `{{hoja_buscar:}}`.
- Ficha «@solicitudes» en Recursos del Asistente (es/en) y el chat del Asistente la recibe en sus recursos.
- `@solicitudes` nunca llega al modelo que redacta (`Directives.strip_tokens`).

**Pruebas.** `sheet_lookup_checks_spec` (3 nuevas): rojo sin caso · ámbar sin hoja · completa sin avisos.
Suite del motor: 797 ejemplos, solo las 6 fallas previas.

**Cómo pedírselo al Asistente.** Después de escribir la ruta: «Analiza el prompt». Si falta algo,
sale pintado en la línea (con el aviso al pasar el mouse) y con punto en el árbol.

### F6 — Pila completa P1–P12 (26/09/2026) ✅

Copia de prueba #10368 en *Agents IA Test*; columna «Pagado» creada en el tipo «Comercial» (cuenta 2).

| # | Escenario | Conv | Resultado |
|---|---|---|---|
| P1 | ej. 11: SOLICITUD 01 (pick up) + SOLICITUD 02 (plana 30 t) | 261 | 2 casos; pick up «no tengo ese equipo»; plana 2A/2B/2C ✅ |
| P2 | ej. 6: grúa 60 t + plana 12 m de 30 t + low boy 50 t, 4 h | 262 | 3 casos; grúa sin equipo; plana y low boy con 3 opciones de 4 h ✅ |
| P3 | reiteración del mismo mensaje | 262 | «Actualicé 3 servicios que ya tenía», mismos casos ✅ |
| P4 | ej. 10: 2 fletes por separado, 6:00 pm – 12:00 am | 263 | 2 casos, opciones de 6 h (18:00–00:00) ✅ |
| P5 | ej. 25: consolidar 2 tramos | 264 | 1 caso, «me falta la fecha» ✅ |
| P6 | ej. 19: entrega y recolección | 265 | 2 casos (Carmen → Villahermosa y regreso) ✅ |
| P7 | «sí» + «Le confirmamos el servicio 2» (requiere pago) | 262 | aparta 2 y 3; solo el 2 queda esperando pago ✅ |
| P8 | «Cancela el low boy» | 262 | caso 3 cancelado y su tarea cancelada ✅ |
| P9 | etiqueta `pago_confirmado` | 262 | «Tu servicio 2️⃣ quedó confirmado»; tarea sin [TENTATIVO] ✅ |
| P10 | ej. 7 con un agente SIN `@solicitudes` | 268 | como siempre: caso normal, pide los datos del tipo de caso ✅ |
| P11 | renta de low boy 50 t por 3 meses | 260 | bloque 1 dic 2026 → 28 feb 2027, evento de día completo ✅ |
| P12 | plana → «sí» → confirmar (pago) → caso a columna «Pagado» | 267 | «Tu servicio 1️⃣ quedó confirmado»; tarea en firme ✅ |

Observaciones (fuera de esta pieza o por configurar):
- P10: el creador de casos normal pidió «Peso y Unidad» aunque el cliente dio «8,800 kg»
  (lectura de campos del tipo «Comercial», no de `@solicitudes`).
- Sin duración dicha, la opción dura lo del agente (30 min, P1). Para servicios, conviene
  `@agendar_calendar(duracion=2h, …)` o que el cliente la diga.
- Grúas, HIAB y pick up salen «no tengo ese equipo en el catálogo» hasta crear la hoja «Equipos».

**Pieza 5 cerrada (F0–F7).**

---

## 14. Pieza 7 — el motor lee los adjuntos (26/09/2026) ✅

**Qué se hizo.** `ContactTrackings::AttachmentText`: el texto de un adjunto llega al motor, al
separador de servicios de `@solicitudes` y al clasificador de rutas (antes solo «[archivo
adjunto: X.pdf]»). Una sola vez por adjunto (caché).
- **Excel (.xlsx)** y **Word (.docx)**: filas, párrafos y tablas, sin IA — `ZipReader` (lector
  ZIP mínimo con Zlib, sin gemas nuevas) + Nokogiri.
- **CSV / texto**: tal cual.
- **PDF**: lo lee la IA (gpt-4o-mini, el PDF va como archivo). Si la IA se niega («Lo siento, no
  puedo…»), no se toma como texto ni se guarda.
- **Correo**: no se probó (no hay canal de correo de prueba).

**Pila de pruebas (copia #10368).**
| Conv | Cliente | Adjunto | Resultado |
|---|---|---|---|
| 269 | «Solicito cotizar y confirmar disponibilidad de lo que viene en la requisición adjunta.» | requisicion.pdf | ❌ la IA se negó a leer el PDF y la negativa se guardó como texto → arreglado (archivo primero, «Extrae el texto…», negativas descartadas) |
| 270 | «Les comparto el programa de unidades en el Excel, favor de programar.» | programa.xlsx | 2 servicios (plana 30 t 12 oct 09:00, low boy 50 t 11:00) con sus horarios ✅ |
| 271 | la misma de la 269, después del arreglo | requisicion.pdf | 2 servicios: grúa 80 t (sin equipo en el catálogo) y plana 30 t 14 oct 10:00 con **3 h** (la duración del PDF) ✅ |

Archivos de prueba: `spec/fixtures/files/solicitudes/` (requisicion.pdf, programa.xlsx,
requisicion.docx). Specs: `attachment_text_spec` (6).

**Cómo pedírselo al Asistente.** Nada que escribir en el Entrenamiento: el motor lee los
adjuntos en todas las rutas. Con `@solicitudes`, una requisición o un programa adjunto se separa
en servicios igual que si el cliente los escribiera.
