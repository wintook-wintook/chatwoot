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

---

## Bitácora — punto 9: casos duplicados (06/10/2026)

Conversación real: **377** (inbox 4, Telegram) → 6 casos (01115–01120) para 2 servicios.

### 1. Qué se hizo

| Causa | Arreglo |
|---|---|
| «Serían los dos para el 3 de octubre»: los casos anteriores no tenían fecha y no coincidían | `registry.rb#same?`: un dato que el caso anterior no tenía ya no cuenta como diferencia (commit anterior) |
| «de centro a paraíso, 14 t y 11 t»: el cliente **corrigió** lugar y capacidad | `extractor.rb`: la IA recibe los casos abiertos numerados (con folio) y dice cuál corrige (`"caso": N`; acepta también el folio) |
| La IA a veces toma «Hiab 11 t» como otro equipo frente a «Hiab 12 t» | `registry.rb#same_kind_pending`: respaldo sin IA — un caso abierto del mismo tipo de equipo, sin tarea e incompleto se corrige; solo «adicional / además / agrega / otro más» abre otro |
| Material = «Hiab 14 a 15 Ton», Peso = capacidad | `fields.rb`: el equipo y sus toneladas no son la carga; `registry.rb`: con varios servicios en un mensaje, cada caso se llena solo con sus datos (no con el mensaje completo) |

Al actualizar un caso también se renueva su título (no se queda con el lugar viejo).

### 2. Cómo funciona

```
Casos ya registrados en esta conversación:      ← se le pasa a la IA
1. Hiab 14 a 15 t · KM10.5 Prefabricado · lun 12 oct (caso 01135)
2. Hiab 12 t · KM10.5 Prefabricado · lun 12 oct (caso 01136)

«…de uno de 14 t y el otro 11 t, de centro a paraíso»
  → {"etiqueta": "Hiab 14 t", …, "caso": 1}, {"etiqueta": "Hiab 11 t", …, "caso": 2}
  → «Actualicé 2 servicios que ya tenía»
```

### 3. Pila de pruebas (Agents IA Test, 493, agente #10368 — los 4 mensajes de la 377, fecha 12 oct)

| Conv. | Resultado |
|---|---|
| 383 | ⚠️ Turno 2 ya no duplica; turno 4 abrió 2 (la IA contestó con el folio «01126» en vez de 1). Campos: Material = equipo |
| 384 | ✅ 2 casos; ⚠️ Peso 11 t en los dos (mensaje completo mezclaba) |
| 385 | ⚠️ 3 casos: la IA tomó «Hiab 11 t» como nuevo frente a «Hiab 12 t» → respaldo sin IA |
| 386 | ✅ **2 casos**, cada uno con su peso, material y ruta; pidió Material y Peso desde el 1.er turno |

Specs nuevas: `extractor_spec.rb` (número y folio), `registry_spec.rb` (case_ref, respaldo, «adicional»). No corridas.

### 4. Cómo pedírselo al Asistente

No hace falta: es del motor de `@solicitudes`; cualquier ruta con `@solicitudes` lo usa.

### Pendiente — punto 3

En la 377 no se creó ninguna cita: no hay hiab en la hoja «Servicio Gruas» («no tengo ese equipo
en el catálogo»). Todas las citas de los agentes de Grúas tienen la fecha pedida, en la base y en
Google (calendarios, cuenta y links de la hoja en America/Mexico_City). Falta que SSUSA aclare si
«no se generó» (faltan los hiab en la hoja) o si fue otra conversación.

---

## Bitácora — punto 1: la palabra «equipo» y recomendar relacionados (06/10/2026)

### 1. Qué se hizo

| Causa | Arreglo |
|---|---|
| «flete de este **equipo**: plataforma articulada Haulotte» → el motor guardaba tipo = «plataforma» y lo relacionaba con las «Plataforma plana» de la hoja (conv. 257, 263) | `extractor.rb`: el tipo es la unidad **de la empresa**; la máquina/equipo **del cliente** es carga. Sin unidad dicha → tipo vacío |
| Lo pedido no está en la hoja (hiab) → solo «no tengo ese equipo en el catálogo» (conv. 377) | `scheduler.rb`: se busca otra vez sin el filtro de texto (`tipo=?`) y con el de números (`peso_max_t>=?`): «ℹ️ No tengo hiab; lo más parecido que tengo» |
| Sin peso ni capacidad para comparar | «no tengo hiab en el catálogo; manejo: Low boy, Plataforma plana extendible, Cama baja, Plataforma plana, Gondola / caja de volteo» (valores de la columna de la hoja) |
| Lo relacionado se apartaba solo | `turn.rb`: lo relacionado solo se **recomienda**; el cliente confirma con «sí» |

### 2. Cómo funciona

```
👤 Necesito un hiab de 14 toneladas … a las 11:00 am … 8 toneladas de varilla
🤖 1️⃣ Hiab 14 t · KM10.5 Prefabricado · lun 12 oct 11:00 (caso 01139)
       ℹ️ No tengo hiab; lo más parecido que tengo:
       🚛 TP-111: Plataforma plana · Peso max t: 40.8 · Largo m: 14.02 · Placas: 74UR8D
       sí hay a las 11:00 → 1A 11:00–12:00 (TP-111)
👤 sí
🤖 📌 Aparté: 1️⃣ Hiab 14 t · lun 12 oct 11:00–12:00 (TP-111)
```

### 3. Pila de pruebas (Agents IA Test 493, agente #10368)

| Conv. | Mensaje | Resultado |
|---|---|---|
| 387 | Hiab 14 t, lun 12 oct 09:00, 8 t de varilla | ⚠️ «No tengo hiab; lo más parecido» ✅ pero lo apartó solo → corregido |
| 388 | Flete de «plataforma articulada Haulotte HA20 de 9.4 t» | ✅ Haulotte = Material (no tipo); «Estas unidades aguantan la carga» (también apartó solo → corregido) |
| 389 | Hiab 14 t 11:00 · luego «sí» | ✅ Recomienda TP-111 sin apartar; con «sí» la aparta y Unidad = TP-111 |
| consola | «hiab» sin peso | ✅ «no tengo hiab en el catálogo; manejo: …» |

Spec nueva: `scheduler_spec.rb` (búsqueda relacionada). No corrida.

### 4. Cómo pedírselo al Asistente

No hace falta: lo hace el motor en cualquier ruta con `@solicitudes` cuyo `{{hoja_buscar:}}`
tenga un filtro de texto (`tipo=?`) y uno de números (`peso_max_t>=?`).
