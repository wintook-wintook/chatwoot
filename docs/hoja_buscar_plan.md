# Plan — `{{hoja_buscar:}}`: agendar en el calendario del remolque elegido

> Solo plan (25/09/2026). Pedido del usuario con el Agente de Grúas SSUSA (#10238):
> buscar en la hoja los remolques que salieron en la conversación, tomar su
> `Calendar_ID` y buscar la disponibilidad **en el calendario de esos remolques**.


> **Dónde está cada cosa (26/09/2026).** Cada fase de este plan (secciones 9–14) trae su **pila de
> pruebas** (conversaciones de *Agents IA Test*) y **cómo pedírselo al Asistente** (texto para
> copiar y pegar). El diseño completo del agente de Grúas y las 26 conversaciones del corpus están
> en `docs/agente_gruas_ssusa_rutas.md`.
>
> | Sección | Fase | Pruebas | Cómo pedírselo |
> |---|---|---|---|
> | 9 | F0–F5 `{{hoja_buscar:}}` + calendario del remolque | 219–222 | ✅ |
> | 10 | Ruta de disponibilidad + arreglos de agenda | 225–235 | ✅ |
> | 11 | Piezas 1 y 2: comparaciones y fuente de datos | 247–249 | ✅ |
> | 12 | Pieza 6: fechas ambiguas | 250–251 | (automático) |
> | 13 | Pieza 3: duración y 24 h | 253–254 | ✅ |
> | 14 | Pieza 4: apartado → confirmado | 255 | ✅ |

---

## 0. Lo que ya existe (medido hoy)

```
Hoja «Servicio Gruas» (fuente 16911, modo FAQ)
  24 filas: remolque | tipo | peso_max_t | … | Calendar_ID
                                               └─ https://calendar.google.com/calendar/embed?src=4e0bc4c5…%40group.calendar.google.com

Agente #10238
  calendar_integration_ids = [65, 9]      ← las dos son aliverio.mx
  booking_calendar_ids     = { "178" => [24 calendarios] }
                                  │
                                  └─ camion01kontrolya@gmail.com: ¡los 24 calendarios de los remolques
                                     YA están configurados!, pero la 178 NO está en
                                     calendar_integration_ids → el motor la ignora y ofrece los
                                     horarios de aliverio.mx («— Admin» en la prueba 210)
```

Consecuencias:

1. **Hoy mismo**, sin código nuevo, agregar la agenda 178 al agente haría que el motor
   ofreciera horarios de los 24 remolques (repartidos). Lo que falta es **limitarlo a los
   remolques de la conversación**, que es lo que resuelve esta directiva.
2. La hoja está en modo FAQ: sus filas viven como texto vectorizado (`knowledge_items`) y
   `google_sheet_rows` está **vacía**. Una búsqueda exacta necesita las filas crudas.
3. El motor ya sabe tratar cada calendario como un recurso aparte
   (`AvailabilitySlotService#resources_for` con `booking_calendars`): mira su ocupación por
   separado y crea la cita en el que esté libre. No hay que inventar la agenda por recurso.

---

## 1. La directiva

```
{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}
               └── la hoja ──┘ └─ buscar ─┘ └─ regresar ─┘
```

| Parte     | Qué es                                            | Ejemplos                                         |
|-----------|---------------------------------------------------|--------------------------------------------------|
| hoja      | nombre de la fuente Google Sheet                  | `Servicio Gruas`                                 |
| buscar    | `columna=valores`; varias condiciones con `;`     | `remolque=?` · `remolque=TP-64,TP-63; estatus_operativo=activo` |
| regresar  | columna(s) a devolver, separadas por coma         | `Calendar_ID` · `Calendar_ID, placas`            |

- Comparación exacta, sin distinguir mayúsculas ni espacios de sobra. **Sin IA**.
- `?` = el valor sale de la conversación (sección 2).
- Sin coincidencias → vacío + «sin resultado». Nunca se completa.

### En la ruta

```
@ruta(solicitud_servicio #solicita_servicio: Quiero un servicio de transporte):
    {{hoja:Servicio Gruas}}
    -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}
    -> @agendar_calendar
```

---

## 2. De dónde sale el `?` (sin IA)

Como la hoja trae la lista completa de valores de la columna (`TP-64`, `TP-63`, … 24),
no hace falta que un modelo «entienda» la conversación: se buscan esos valores, tal cual,
en los últimos mensajes.

```
últimos 6 mensajes (bot + cliente)
   «Te recomiendo la plataforma TP-37 o la TP-95…»     ← bot
   «La TP-95 está bien»                               ← cliente
          │
          ▼  valores conocidos de la columna «remolque» (24)
   coincidencias, el más reciente primero:  TP-95, TP-37
          │
          ▼  si el cliente nombró uno, ése gana:        [TP-95]
             si no, los que ofreció el bot:            [TP-37, TP-95]
             si ninguno:                               vacío → sección 4
```

---

## 3. Flujo completo en un turno de agenda

```
cliente: «sí, agéndalo»
   │
   ▼
Router → :book_appointment   (ruta solicitud_servicio, tiene @agendar_calendar)
   │
   ▼
HojaBuscar ─ filas de «Servicio Gruas» ─ remolque ∈ [TP-95] → Calendar_ID
   │            (google_sheet_rows)
   ▼
normalizar: URL embed → id de calendario
   https://…/embed?src=7eef…%40group.calendar.google.com&ctz=…  →  7eef…@group.calendar.google.com
   │
   ▼
¿qué agenda (integración) tiene ese calendario en booking_calendar_ids?  → 178
   │
   ▼
AvailabilitySlotService(
   calendar_integration_ids: [178],
   booking_calendars: { "178" => ["7eef…@group.calendar.google.com"] })   ← SOLO ese remolque
   │
   ▼
«Para la TP-95 tengo: 1️⃣ lun 28 sep 10:00 … ¿Cuál te queda mejor?»
   │
   ▼  el cliente elige 2
cita creada en el calendario de la TP-95 (el slot guarda google_calendar_id, ya existe)
```

El `Calendar_ID` **nunca** llega al cliente ni al modelo: se resuelve en Ruby y solo
alimenta la agenda.

---

## 4. Casos borde

| Caso | Qué hace |
|------|----------|
| No se nombró ningún remolque | No ofrece horarios de todos: el agente pregunta qué unidad (o sigue el flujo de la ruta para elegirla). |
| Se nombraron varios | Horarios de esos calendarios, repartidos (ya lo hace `balance_slots`); cada horario dice de qué remolque es. |
| El calendario no está en ninguna agenda del agente | No se ofrece ese remolque; aviso en el log y en el comprobador (sección 6). |
| La agenda 178 no puede leerse (token vencido) | Igual que hoy: esa agenda no ofrece horarios → escalar. |
| Remolque con `estatus_operativo` ≠ activo | Solo si el prompt lo pide con `; estatus_operativo=activo`. |
| El cliente ya tiene cita | Igual que hoy (`inform_existing_appointment`). |

---

## 5. Filas crudas también en modo FAQ

`GoogleSheetSyncJob` hoy borra `google_sheet_rows` en modo FAQ. Cambio: **guardar las filas
crudas en los dos modos** (son pocas; la de grúas, 24). El modo FAQ sigue vectorizando igual
para `{{hoja:}}`; `{{hoja_buscar:}}` lee las filas. Así no hay que cambiar la hoja de modo.

---

## 6. Comprobador y Asistente

- **Comprobador** (en rojo/ámbar con el aviso al pasar el mouse):
  - 🔴 la hoja no existe · la columna de búsqueda o de regreso no está en los encabezados
  - 🔴 directiva mal cerrada (falta `}}` o una de las 3 partes)
  - 🟡 los calendarios de la columna no están en ninguna agenda del agente
    (hoy: la 178 no está en «Calendarios» → aviso con cómo arreglarlo)
- **Catálogo del motor / Recursos**: la directiva aparece con su ejemplo.
- **Directivas sueltas (D7)**: `{{hoja_buscar:}}` fuera de una ruta se marca igual que `{{hoja:}}`.

---

## 7. Fases

| Fase | Qué | Dónde |
|------|-----|-------|
| F0 | Filas crudas en los dos modos + re-sincronizar «Servicio Gruas» | `google_sheet_sync_job.rb` |
| F1 | Parser de la directiva + búsqueda exacta + normalizar Calendar_ID | `knowledge_base/directives.rb`, `SheetLookupService` (nuevo) |
| F2 | `?` desde la conversación (valores conocidos en los últimos mensajes) | `SheetLookupService` |
| F3 | Agenda limitada a los calendarios encontrados | `contact_tracking_response_analyzer_job.rb` (`slot_service_for`) |
| F4 | Comprobador + catálogo del Asistente + i18n | `validator/*`, `engine_catalog.rb` |
| F5 | Pila de pruebas con Grúas hasta crear la cita en el calendario del remolque (agenda 178, de prueba) | Agents IA Test |

Cada fase con sus specs; F3 con spec de que el slot ofrecido y la cita usan el calendario
del remolque.

---

## 8. Decisiones (25/09/2026)

1. **Agenda**: resuelto por el usuario. El agente ahora tiene
   `calendar_integration_ids = [178]` (camion01kontrolya@gmail.com) con sus 24 calendarios en
   `booking_calendar_ids`; aliverio.mx ya no está. Lo de la sección 0 («la 178 no está») era
   la foto de antes del cambio.
2. **Sin remolque nombrado** → el agente **pregunta cuál**. No se ofrecen horarios de todos.
3. **Varios remolques nombrados** → horarios de **todos los nombrados**, repartidos, y cada
   horario dice de qué remolque es.
4. **Pruebas** → los calendarios de la agenda 178 son de prueba: en F5 sí se puede llegar a
   crear la cita (a diferencia de aliverio.mx, que sigue prohibido).

---

## 9. Resultado F5 (25/09/2026)

Copia de prueba del agente: **#10368 «Grúas SSUSA — prueba hoja_buscar»** (la #10238 no se tocó),
ruta `solicitud_servicio` con `{{hoja:Servicio Gruas}} -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar`.

| Conv | Cliente | Resultado | Calendario usado |
|------|---------|-----------|------------------|
| 219 | «Me interesa la TP-64, ¿qué horarios tiene?» | 5 horarios | TP-64 ✅ |
| 220 | «Quiero agendar un servicio de remolque» | «¿Para cuál remolque quieres agendar?» | ninguno ✅ |
| 221 | excavadora → el agente recomienda TP-93 → «agéndame en la que me recomiendes» | 5 horarios | TP-93 ✅ |
| 222 | «Quiero agendar la TP-63» → «1» → «sin correo» | cita creada vie 25/09 17:00 | TP-63 ✅ (`appointment_calendar_gid`) |

Pendiente de configuración (no de código): con «Presentación de horarios» = *detallada* cada
horario dice el nombre del agente de Google («— Jose Luis Herrera»). Con **por calendario**
salen agrupados bajo «📅 TP-64», que es lo que pide la decisión 3.

**Cómo pedírselo al Asistente** (Agentes IA → Asistente → abrir el agente → chat):
```
En la ruta disponibilidad_remolque, que no consulte ninguna fuente y que después de la flecha
diga exactamente: {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```
Luego «Analiza el prompt». Requisito: la hoja «Servicio Gruas» con columna `Calendar_ID` y los
calendarios marcados en una agenda del agente.

---

## 10. Ruta de disponibilidad (25/09/2026)

Problema medido: «¿qué horarios tienen la TP-64 y la TP-63 para mañana?» a veces la IA de
citas (RouterService) la tomaba como plática → contestaba la hoja (y con Calendar_ID en el
contexto le pasó al cliente los links de los calendarios; ya corregido: las columnas que
regresa una `{{hoja_buscar:}}` no llegan al modelo en `{{hoja:}}`).

Regla del motor: una ruta **sin fuente** con `{{hoja_buscar:}} -> @agendar_calendar` es de
disponibilidad. Si el mensaje cae ahí, va a horarios sin preguntarle a la IA si es cita; la
fecha («mañana») se lee del mensaje. Si ya tiene cita, o la IA trajo mover/cancelar, se respeta.

```
@ruta(disponibilidad_remolque #consulta_producto: qué horarios tiene la TP-64, disponibilidad de un remolque para mañana, cuándo está libre un remolque, quiero agendar un remolque): - -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
@ruta(solicitud_servicio #tracking: Quiero un servicio de transporte): {{hoja:Servicio Gruas}} -> @crear_ticket(tipo=Comercial, prioridad=media)
@ruta(consulta_catalogo #consulta_producto: Qué tipos de grúas manejan): {{hoja:Servicio Gruas}}
```

| Conv | Cliente | IA de citas | Resultado |
|------|---------|-------------|-----------|
| 227 | ¿horarios TP-64 y TP-63 para mañana? | cita | «Mañana sábado no hay servicio…» + lunes ✅ |
| 228 | (igual) | plática | igual ✅ (la ruta decidió) |
| 229 | (igual) | plática | igual ✅ (la ruta decidió) |
| 230 | Quiero agendar un remolque | cita | «¿Para cuál remolque…?» ✅ |
| 231 | ¿Qué capacidad tiene la TP-64? | plática | hoja: 60 t, sin links ✅ |
| 232 | ¿Cuándo está libre la TP-93? | cita | horarios del calendario TP-93 ✅ |

**Más pruebas de esta fase** (arreglos de agenda, 25/09):

| Conv | Cliente | Resultado |
|------|---------|-----------|
| 225 | ¿horarios de TP-64 y TP-63 para mañana? | «Mañana sábado no hay servicio. Los primeros horarios son el lunes 28» ✅ |
| 226 | (igual, antes del arreglo) | links de calendarios al cliente ❌ → arreglado: `Calendar_ID` ya no llega al modelo |
| 233 | ¿Cuándo está libre la TP-93? (agente #10238) | horarios de la TP-93 ✅ |
| 234 | TP-93 para el martes → «¿y en la tarde?» | martes 09–11 → martes 12:00–14:30 ✅ |
| 234 | «¿cuándo está libre la TP-58?» con horarios abiertos | horarios de la TP-58 (antes repetía los de la TP-93) ✅ |
| 234 | «2» + «sin correo» | cita TP-64 lun 28 09:30 ✅ |
| 235 | otro cliente: ¿TP-64 el lunes 28 a las 9:30? | «Uy, ese horario no está disponible» + cercanos ✅ |

**Cómo pedírselo al Asistente:**
```
Agrega una ruta disponibilidad_remolque #consulta_producto con frases: qué horarios tiene la
TP-64, cuándo está libre un remolque, disponibilidad para mañana, quiero agendar un remolque.
Sin fuente, y después de la flecha exactamente:
{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```
En la ficha del agente: **Presentación de horarios = por calendario** (cada horario dice su remolque).

---

## 11. Piezas 1 y 2 (26/09/2026)

**Pieza 1 — comparaciones.** `columna>=valor`, `<=`, `>`, `<` (números) y `columna!=valores`.
Con `?`, el número sale del mensaje más reciente del cliente que traiga uno **con la unidad de
la columna** (`ContactTrackings::SheetNumbers`): toneladas (t, ton, toneladas; kg ÷ 1000),
metros (m, mts, metros) o la palabra de la columna («5 extensiones»). Con `>=` manda el mayor;
con `<=`, el menor. Comparación de textos sin acentos.

**Pieza 2 — fuente de datos.** Como FUENTE de la ruta (antes de la flecha), `{{hoja_buscar:}}`
responde con las filas exactas (`KnowledgeBaseResponseService#perform_sheet_lookup`); después de
la flecha sigue siendo AGENDA (`SheetLookup.agenda_specs`). Solo las columnas de agenda se
esconden del contexto de `{{hoja:}}`.

| Conv | Cliente | Resultado |
|------|---------|-----------|
| 247 | remolque para 50 toneladas | solo TP-64 (60 t) ✅ |
| 248 | ¿qué placas tiene la TP-63 y qué tracto la jala? | «92UN8A, tracto TP-55» (exacto) ✅ |
| 249 | carga de 8,800 kg | 8.8 t → horarios repartidos entre los que aguantan ✅ |

**Cómo pedírselo al Asistente:**
```
Pieza 1 — en la ruta disponibilidad_equipo, después de la flecha exactamente:
{{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}} -> @agendar_calendar

Pieza 2 — agrega la ruta datos_remolque #consulta_producto con frases: qué placas tiene la
TP-63, dame los datos de la TP-64, qué tracto jala la TP-93. Como FUENTE (antes de la flecha):
{{hoja_buscar: Servicio Gruas | remolque=? | tipo, placas, peso_max_t, jalado_por}}
```
Regla para recordar: **antes de la flecha = datos para responder; después = agenda.**

---

## 12. Pieza 6 — fechas ambiguas (26/09/2026)

Un día de la semana sin número («el día lunes», «el martes a las 10») es ambiguo
(`ContactTrackings::AmbiguousDate`, sin IA; «lunes 28», «01 de junio», «30/06» no lo son).
En la agenda — primera oferta y negociación — el motor:
- con hora libre: NO agenda en firme; la ofrece como opción 1 con la fecha completa;
- sin hora, o con hora ocupada: antepone la fecha completa a los horarios.

| Conv | Cliente | Respuesta | Cita creada |
|------|---------|-----------|-------------|
| 250 | ¿disponibilidad de la TP-64 el lunes a las 12:00? | «Entiendo que es el lunes 28 de septiembre, a las 12:00. Está libre: 1️⃣ … Responde 1 para apartarlo» | no ✅ |
| 251 | ¿disponibilidad de la TP-63 el día martes? | «Entiendo que es el martes 29 de septiembre. Estos son los horarios de ese día: …» | no ✅ |

**Cómo pedírselo al Asistente:** no hace falta; el motor lo hace en toda ruta que agenda.

---

## 13. Pieza 3 — duración y horario 24 h (26/09/2026)

`@agendar_calendar(duracion=?, horario=24h)` (`ContactTrackings::CalendarOptions`):
- `duracion=90` / `duracion=2h` fija; `duracion=?` la lee del mensaje, sin IA («una hora», «jornada
  de 16 horas», «6:00 pm – 12:00 am», «2 hrs», «45 minutos»; una hora del día no cuenta; tope 24 h);
  si no la dijo, la del agente.
- `horario=24h`: cualquier hora de cualquier día (`AvailabilitySlotService` con `working_hours: ALL_DAY`);
  el servicio puede cruzar la medianoche.
- Servicios de más de 60 min se ofrecen cada hora (antes: cada «duración»).
- El comprobador marca en rojo una opción que el motor no entiende (`horario=noche`).
- Arreglo encontrado al probar: «domingo 4 de octubre» daba el domingo 27 — con día de semana y
  fecha que coinciden, ahora manda la fecha.

| Conv | Cliente | Resultado |
|------|---------|-----------|
| 254 | TP-64 domingo 4 de octubre, jornada de 16 horas | domingo 4 oct 00:00–16:00, 01:00–17:00… ✅ |
| 253 | TP-93 el 5 de octubre, 6:00 pm – 12:00 am | 18:00–00:00 (6 h) libre → pide correo para confirmar ✅ |

**Cómo pedírselo al Asistente:**
```
En la ruta disponibilidad_equipo cambia la acción final por exactamente:
@agendar_calendar(duracion=?, horario=24h)
```
Opciones válidas: `duracion=?` (la dice el cliente), `duracion=90` (minutos), `duracion=2h`,
`horario=24h`. Otra cosa sale en rojo en el comprobador.

---

## 14. Pieza 4 — apartado → confirmado (26/09/2026)

`@agendar_calendar(modo=tentativo)` + `@confirmar_servicio[(requiere=pago)]` +
etiqueta `pago_confirmado` (`ServiceConfirmationListener` → `PaymentConfirmedJob`).
Columna nueva `contact_trackings.appointment_status` (tentative / pending_payment / confirmed;
nil = como siempre). Prueba de punta a punta: conversación 255 (ver
`docs/agente_gruas_ssusa_rutas.md` §7, que lleva la bitácora por fase con pruebas y cómo
pedírselo al Asistente).

**Pila de pruebas (conversación 255):**

| Paso | Cliente / equipo | Resultado |
|------|------------------|-----------|
| 1 | ¿TP-64 el lunes 5 de octubre a las 10:00? dura 2 horas → «sin correo» | «📌 Te aparté… pendiente de confirmar»; calendario «[TENTATIVO]» 10:00–12:00 ✅ |
| 2 | «Le confirmamos el servicio, favor de presentarse a las 10:00» | pide el pago + nota al equipo; estado pending_payment ✅ |
| 3 | el equipo pone la etiqueta `pago_confirmado` | «✅ Recibimos tu pago…»; calendario sin [TENTATIVO]; estado confirmed ✅ |

**Cómo pedírselo al Asistente:**
```
1) En la ruta disponibilidad_equipo la acción final debe ser exactamente:
   @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
2) Agrega la ruta confirmacion_servicio #confirmado con frases: le confirmamos el servicio,
   favor de presentarse mañana, solicito que el servicio se presente el día, queda confirmado.
   Sin fuente, y después de la flecha: @confirmar_servicio(requiere=pago)
3) En [REGLAS]: «Un horario apartado queda pendiente hasta que el cliente confirme; si pide el
   pago, no digas que está confirmado hasta recibirlo.»
```
Después «Analiza el prompt»: si avisa que `#pago_confirmado` no existe → botón **Crearla**.
Sin pago: `@confirmar_servicio` (sin paréntesis) lo deja en firme en cuanto el cliente confirma.
