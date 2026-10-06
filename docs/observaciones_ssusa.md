# Observaciones SSUSA

Rama: `fix/observaciones_ssusa` (desde `develop`, 06/10/2026)

## Pendientes

- [ ] **1. Palabra "equipo".** Cuando el cliente menciona "equipo", el bot intenta relacionarlo con algo y no debe. Solo recomienda los relacionados; si no encuentra el pedido, ofrece uno relacionado.
- [ ] **2. Campos obligatorios de "Renta Unidades".** El tipo de caso los marca como obligatorios, pero no se llenan. Si vienen en la solicitud, el bot los llena con eso; si no, los pregunta.
- [ ] **3. Fecha de la agenda.** El evento en el calendario no se creó con la fecha que pidió el cliente.
- [ ] **4. Describir la grúa antes de la disponibilidad.** Antes de dar horarios, el bot da la descripción y especificaciones de la grúa, para que el cliente confirme que le sirve.
- [ ] **5. Disponibilidad según el horario.**
  - Si el cliente da horario → responder si hay o no (sin lista).
  - Si no da horario → pedirlo.
  - Si no hay → decir qué disponibilidad sí hay.
  - Si pide grúa y ya dice cuándo → agendar directo si hay.
- [ ] **6. Conectar con CRM Zeus.** Validar si el contacto es cliente o no.
- [ ] **7. No dado de alta → humano.** Mensajes de alguien que no es cliente se escalan directo a un agente.
- [ ] **8. (PENDIENTE DESARROLLO) Estatus de la organización en CRM Zeus.** Validar el estatus del cliente/organización.
- [ ] **9. Casos duplicados.** En una conversación se crearon 6 casos del mismo servicio; el bot no siguió el hilo de la conversación.

---

## Bitácora — puntos 2, 4 y 5 (06/10/2026)

Agente: **Grúas SSUSA — prueba hoja_buscar** (#10368, cuenta 2). Solo cambia el código de
`@solicitudes` (`app/services/contact_trackings/service_requests/`), que hoy usa únicamente este
agente. El motor de agenda de los demás agentes no se tocó.

### 1. Qué se hizo

| Punto | Archivo | Cambio |
|---|---|---|
| 2 | `service_requests/fields.rb` (nuevo) | Llena los campos del tipo de caso de cada servicio con el mismo extractor que usa `@crear_ticket`. Los campos y cuáles son obligatorios salen del tipo de caso, no del código. |
| 2 | `service_requests/registry.rb` | Al crear o actualizar el caso guarda los campos y anota los obligatorios que faltan (`metadata.faltan_campos`). `complete!` completa un caso con la respuesta del cliente. |
| 2 | `service_requests/turn.rb` | «Me falta…» pregunta los obligatorios vacíos del tipo de caso (antes solo fecha y lugar). Si el mensaje solo trae los datos pedidos, completa el caso abierto. |
| 2 | `contact_tracking_response_analyzer_job.rb` | Si la respuesta («a las 10», «es escombro») cae en otra ruta, igual completa el caso pendiente. |
| 9 (de paso) | `registry.rb` | Un caso que no tenía fecha u origen se completa cuando llegan, en vez de abrir otro. |
| 4 | `service_requests/scheduler.rb` + `turn.rb` | Antes del horario, una línea 🚛 con los datos de la unidad, sacados de la hoja. |
| 5 | `scheduler.rb` + `turn.rb` + `choice.rb` | Con hora libre: se aparta directo. Con hora ocupada: «a las 08:00 no hay; lo que sí hay → …». Sin hora: se pide la hora, sin listar la agenda. |

### 2. Cómo funciona

Las columnas de la descripción las elige la ruta: la 1.ª columna que regresa `{{hoja_buscar:}}`
es el calendario y las demás describen la unidad.

```
{{hoja_buscar: Servicio Gruas | tipo=?; peso_max_t>=? | Calendar_ID, tipo, peso_max_t, largo_m, placas}}
                                                        └calendario┘ └──── descripción de la unidad ────┘
```

Ejemplo de respuesta (hora pedida y libre, modo tentativo):

```
Recibí 1 servicio:

1️⃣ Plana 30 t · Centro → Paraíso · sáb 10 oct 08:00 · 📌 apartado (caso 01121)
    🚛 TP-63: Plataforma plana extendible (se alarga) · Peso max t: 40.8 · Largo m: 16.15 · Placas: 92UN8A
    ✅ Sí hay a las 08:00: te lo aparté de 08:00 a 10:00 (TP-63)

Para programarlos me falta: del 1️⃣ Material a transportar y cantidad, Peso.
Queda apartado; cuando me confirmes el servicio lo dejo en firme.
```

Sin hora: `Para programarlos me falta: del 1️⃣ …, a qué hora lo necesitas.` (no lista horarios).
Hora ocupada: `a las 08:00 no hay; lo que sí hay → 1A 09:00–11:00 (TP-63) · 1B …`.

### 3. Pila de pruebas

- Specs actualizadas/nuevas: `spec/services/contact_trackings/service_requests/scheduler_spec.rb`,
  `registry_spec.rb`, `turn_spec.rb`. **No corridas** (RSpec usa la base de dev).
- Revisión en consola (solo lectura): la descripción de unidades sale de la hoja real
  («Plataforma plana extendible (se alarga) · Peso max t: 40.8 · Largo m: 16.15 · Placas: 92UN8A»).
- En vivo, Agents IA Test (493), agente #10368, 06/10/2026:

| Conv. | Mensajes del cliente | Resultado |
|---|---|---|
| 378 | Plana 30 t, vie 9 oct 08:00, Centro → Paraíso, escombro 25 t | ✅ 6 campos llenos, unidad TP-111 descrita, apartado directo 08:00–09:00 (caso 01121) |
| 379 | Plana vie 9 oct Villahermosa → Comalcalco · luego «a las 10 am, son 20 toneladas de varilla» | ⚠️ 1.er turno no pidió Material (copió «plana» del equipo). 2.º turno: mismo caso completado y apartado 10:00 (01122) |
| 380 | Mismo 1.er mensaje (reproducir) | ❌ Material = «plana» → arreglado en `fields.rb` (el equipo no es la carga); 5/5 extracciones correctas después |
| 381 | Mismo 1.er mensaje tras el arreglo | ✅ Pide Material, Peso y la hora; sin listar agenda (01124) |

| 382 | Plana vie 9 oct Cárdenas → Huimanguillo · luego «a las 12:00 hrs, son 18 toneladas de tubería» | ✅ No pide «Unidad»; al apartar queda Unidad = TP-111 (caso 01125). Comprobador: válido, sin hallazgos |

- Sin probar en vivo: hora pedida **ocupada** (con 13 planas siempre hay una libre); lo cubre la spec.

### Campo de la unidad asignada — `@solicitudes(asignar=campo)`

El campo «Unidad» de Renta Unidades es la grúa asignada, no la unidad del peso (antes salía «t»).
Con `@solicitudes(asignar=unidad)` ese campo:
- no lo llena la IA ni se le pregunta al cliente;
- lo llena el sistema al apartar (directo o cuando el cliente elige «1A») con el nombre de la
  unidad (TP-111). Si se mueve el servicio, se actualiza.

`asignar=` recibe la **clave** del campo del tipo de caso; otro agente puede usar otro campo.

### 4. Cómo pedírselo al Asistente

> En la ruta solicitud_servicio, cambia el {{hoja_buscar:}} para que regrese también la
> descripción de la unidad: `{{hoja_buscar: Servicio Gruas | tipo=?; peso_max_t>=? | Calendar_ID, tipo, peso_max_t, largo_m, placas}}`.
> Calendar_ID tiene que quedar primero.

> En la ruta solicitud_servicio cambia `@solicitudes` por `@solicitudes(asignar=unidad)`, para que
> el campo Unidad del caso se llene con la grúa apartada.
