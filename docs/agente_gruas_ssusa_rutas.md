# Agente de Grúas SSUSA — rutas, conversaciones de ejemplo y cómo pedírselo al Asistente

> Documento de trabajo, 26/09/2026. Agente **#10238 «Agente de Grúas SSUSA»**, cuenta 2.
> Base: las 26 solicitudes reales de clientes que SSUSA recibe por correo.
>
> **Cómo leerlo**
> - ✅ **HOY** — el motor ya lo hace; el Asistente lo puede escribir y funciona.
> - 🔧 **REQUIERE MOTOR** — la directiva o el comportamiento todavía no existe. Si se escribe
>   hoy, el comprobador la marca o el motor la ignora. Está aquí para que el diseño quede
>   completo y se sepa qué pedir después.

---

## 0. En una página

```
                         ┌──────────────── mensaje del cliente ────────────────┐
                         │ «confirmen disponibilidad de grúa 40 t el domingo…» │
                         └──────────────────────────┬──────────────────────────┘
                                                    ▼
                          ¿qué ruta? (el motor lee las FRASES DEL CLIENTE de cada ruta)
   ┌───────────────┬───────────────┬──────────────┼──────────────┬────────────────┬───────────────┐
   ▼               ▼               ▼              ▼              ▼                ▼               ▼
disponibilidad  solicitud_     cotizacion    confirmacion_  asignacion_      seguimiento_    consulta_
_equipo         servicio                     servicio       coordinador      cambios         catalogo
   │               │               │              │              │                │               │
horarios del    junta datos,   tarifas o      tentativo →    datos de         mover/cancelar  dudas técnicas
calendario del  abre caso      caso Comercial en firme       unidad y         la cita, o      del equipo
equipo nombrado «Solicitud de                (pago →        operador         caso de
(o por capacidad) transporte»                etiqueta)      (hoja Unidades)  seguimiento
```

| Qué | Hoy | Falta |
|---|---|---|
| Elegir el equipo por su **nombre/número** (TP-64) y dar sus horarios | ✅ `{{hoja_buscar:}}` | — |
| Elegir el equipo por **lo que pide** (grúa ≥ 80 t, HIAB 12 t) | ✅ `{{hoja_buscar:}}` con `>=`, `<=`, `!=` (26/09) | hoja «Equipos» (se configura) |
| Abrir **un** caso con los datos del servicio | ✅ `@crear_ticket` | tipo de caso con campos (se configura) |
| **Varios** servicios en un mensaje → varios casos y citas | ❌ reusa el caso abierto | 🔧 `@solicitudes` |
| Agendar a las 03:00, domingo, nocturno, jornada | ✅ `@agendar_calendar(duracion=?, horario=24h)` (26/09) | rentas de días/meses (tope hoy: 24 h) |
| Solicitud ≠ confirmación (no agendar en firme sin confirmar) | ✅ `@agendar_calendar(modo=tentativo)` + `@confirmar_servicio(requiere=pago)` (26/09) | — |
| «El día lunes» sin número | ✅ dice la fecha completa y no aparta sin «1» (26/09) | — |
| Responder con datos de unidad y operador (tabla de 9 campos) | ✅ `{{hoja_buscar:}}` como fuente de la ruta (26/09) | hoja «Unidades» (se configura) |
| Cotizar | ❌ siempre «te contacta un asesor» | hoja «Tarifas» en modo Datos (se configura) |
| Leer PDF / Excel adjuntos | ❌ | 🔧 extraer texto de adjuntos |

---

## 1. Lo que se configura antes (sin programar)

| # | Qué | Dónde | Estado |
|---|---|---|---|
| 1 | Hoja **«Servicio Gruas»** — 24 remolques con `Calendar_ID` | Base de Conocimiento | ✅ existe, sincronizada |
| 2 | Hoja **«Equipos»** — grúas, HIAB, torton, rabón, pick up, camión 350, tractos | Base de Conocimiento | ❌ crear |
| 3 | Hoja **«Unidades»** — económico, operador, teléfono, marca, modelo, año, placas tracto, placas remolque, color | Base de Conocimiento | ❌ crear |
| 4 | Hoja **«Tarifas»** (modo **Datos**) — equipo, esquema (hora/jornada 8/12/16/24, viaje, mes), precio, incluye operador/combustible | Base de Conocimiento | ❌ crear |
| 5 | Calendarios de cada equipo, marcados en la agenda del agente | Agente → Calendarios | ✅ los 24 remolques (agenda 178); ❌ grúas/HIAB |
| 6 | Tipo de caso **«Solicitud de transporte»** con campos obligatorios: folio, origen, destino, carga, peso, fecha, hora | Tickets → Tipos de caso | ❌ crear (hoy existen Comercial, Renta Unidades, Seguimiento interno) |
| 7 | Etiquetas de las rutas | Se crean desde el Asistente con **«Crearla»** | existen: `solicita_servicio`, `solicita_cotizacion`, `consulta_producto`, `tracking` · faltan: `disponibilidad`, `confirmado`, `asignacion`, `reprogramacion` |
| 8 | **Presentación de horarios = por calendario** | Agente | ✅ ya puesto |

Columnas sugeridas de la hoja **«Equipos»** (una fila por equipo físico):

```
economico | tipo            | capacidad_t | extensiones | largo_m | certificado_vigente | base | Calendar_ID
TP-118    | Torton c/hiab   | 12          | 4           | 7       | sí                  | CDC  | https://calendar.google.com/…
GR-80A    | Grúa            | 80          |             |         | sí                  | CDC  | https://calendar.google.com/…
```

---

## 2. Las rutas

Cada ruta: **nombre · etiqueta · frases del cliente · de dónde saca la respuesta · si no resuelve**.
Las frases salen del patrón A del corpus (disparadores reales). El motor elige la ruta
leyendo **solo** esas frases: escríbelas como las escribe el cliente, no como las resume SSUSA.

### 2.1 `disponibilidad_equipo` — horarios del equipo nombrado

**HOY ✅** (ya está en el agente como `disponibilidad_remolque`; solo remolques de la hoja «Servicio Gruas»)
```
@ruta(disponibilidad_equipo #disponibilidad: qué disponibilidad tiene la TP-64, cuándo está libre un remolque, de su amable confirmación para la disponibilidad de, confirmando la disponibilidad de, disponibilidad para mañana, quiero agendar un remolque): - -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```
- Sin fuente (`-`) + `{{hoja_buscar:}} -> @agendar_calendar` = **ruta de disponibilidad**: va directo a horarios.
- Si el cliente no nombró el equipo: «¿Para cuál remolque quieres agendar?».
- Si el día pedido no se trabaja: «Mañana sábado no hay servicio. Los primeros horarios son el lunes 28».

**HOY ✅ por capacidad** (desde 26/09; con la hoja «Equipos» creada)
```
@ruta(disponibilidad_equipo #disponibilidad: …mismas frases…, grúa de 40 toneladas, hiab de 12 toneladas, remolque para 50 toneladas): - -> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}} -> @agendar_calendar
```
- `capacidad_t>=?` toma el número que dijo el cliente **con su unidad** («80 toneladas», «26 t»,
  «8,800 kg» → 8.8). Si dijo dos, usa el mayor. Fechas y horas no cuentan como toneladas.
- `tipo=?` reconoce el tipo aunque venga sin acento («grua» = «Grúa»).
- Probado con la hoja actual: «remolque para 50 toneladas» → solo la TP-64 (60 t).

**HOY ✅ completo** (26/09): capacidad + duración + 24 h + apartado
```
@ruta(disponibilidad_equipo #disponibilidad: …): - -> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}} -> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
```

### 2.2 `solicitud_servicio` — juntar datos y abrir el caso

**HOY ✅**
```
@ruta(solicitud_servicio #solicita_servicio: solicito su apoyo para programar una unidad, requerimos programar un camión, su apoyo con la gestión de la siguiente solicitud, favor de programar una plana, necesito mover una excavadora, transporte de materiales de, flete de maquinaria): {{hoja:Servicio Gruas}} -> @crear_ticket(tipo=Comercial, prioridad=media)
```
Cuando exista el tipo de caso: `@crear_ticket(tipo=Solicitud de transporte, prioridad=media)` — el
motor pide solo, una vez, los campos obligatorios que falten.

**CON MOTOR 🔧** (varias solicitudes en un mensaje → un caso y una cita tentativa por cada una)
```
@ruta(solicitud_servicio #solicita_servicio: …): {{hoja:Equipos}} -> @solicitudes -> @crear_ticket(tipo=Solicitud de transporte) -> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
```

### 2.3 `cotizacion` — precio

**HOY ✅** (sin tarifas: junta datos y pasa a Comercial)
```
@ruta(cotizacion #solicita_cotizacion: me podrían cotizar, solicito cotización, favor de cotizar por jornada, cuánto cuesta, renta por hora, jornada de 8 y 12 horas, precio de las horas de hiab, renta mensual, propuesta económica): {{hoja:Servicio Gruas}} -> @crear_ticket(tipo=Comercial, prioridad=media)
```
Con la hoja «Tarifas» (se configura, no requiere motor):
```
@ruta(cotizacion #solicita_cotizacion: …): {{hoja:Tarifas}} -> @crear_ticket(tipo=Comercial, prioridad=media)
```
Renta de meses (ejemplo 18): `@crear_ticket(tipo=Renta Unidades, prioridad=media)`.

### 2.4 `confirmacion_servicio` — pasar de solicitud a servicio en firme

**HOY ✅** (desde 26/09). Dos piezas que van juntas:
1. La ruta que aparta usa `modo=tentativo` → el horario se aparta como «[TENTATIVO]» (ocupa el
   calendario: nadie más lo toma).
2. Esta ruta lo deja en firme — o pide el pago:
```
@ruta(confirmacion_servicio #confirmado: le confirmamos el servicio, favor de presentarse mañana, solicito que el servicio se presente el día, confirmamos en firme, queda confirmado): - -> @confirmar_servicio(requiere=pago)
```
- `@confirmar_servicio` → en firme al instante (quita «[TENTATIVO]» del evento).
- `@confirmar_servicio(requiere=pago)` → le pide el pago al cliente y deja nota al equipo; queda
  en firme cuando una persona le pone a la conversación la etiqueta **`pago_confirmado`**
  (el cliente recibe «✅ Recibimos tu pago…»).
- Requiere la etiqueta `pago_confirmado` en la cuenta (el comprobador avisa y ofrece «Crearla»).
- Si no hay nada apartado, esta ruta no hace nada especial.

### 2.5 `asignacion_coordinador` — «favor de confirmar datos de unidad y operador»

**HOY** ⚠️ no hay de dónde sacar operador ni tracto: abre caso interno.
```
@ruta(asignacion_coordinador #asignacion: favor de asignar este servicio al proveedor SSUSA, modalidad On Call, favor de confirmar datos de unidad y operador, compartiendo los datos del operador y de la unidad asignada, consolidar este servicio): - -> @crear_ticket(tipo=Seguimiento interno, prioridad=alta)
```
**HOY ✅ con la hoja «Unidades»** (desde 26/09: `{{hoja_buscar:}}` como FUENTE responde con las filas exactas)
```
@ruta(asignacion_coordinador #asignacion: …): {{hoja_buscar: Unidades | economico=? | operador, telefono, marca, modelo, anio, placas_tracto, placas_remolque, color}} -> @crear_ticket(tipo=Seguimiento interno)
```
- Antes de la flecha = DATOS para responder; después de la flecha = AGENDA.
- Si no nombró la unidad, pregunta cuál; si no existe, lo dice sin inventar.
- Probado con la hoja actual: «¿Qué placas tiene la TP-63 y qué tracto la jala?» → «placas
  92UN8A, jalada por el tracto TP-55».

### 2.6 `seguimiento_cambios` — reprogramar, cancelar, corregir datos

**HOY ✅** (mover y cancelar funcionan para la cita de la conversación)
```
@ruta(seguimiento_cambios #reprogramacion: vamos a reprogramar, cambio operativo, la entrega no se podrá realizar, cambiar la fecha, cancelar el servicio, se corrige la medida, tomo referencia de): - -> @agendar_calendar
```
🔧 Con `@solicitudes`: mover o cancelar **un** servicio de varios («cancela el HIAB del muelle 13»).

### 2.7 `consulta_catalogo` — dudas técnicas del equipo

**HOY ✅**
```
@ruta(consulta_catalogo #consulta_producto: qué tipos de grúas manejan, qué capacidad tiene la TP-64, cuántas extensiones tiene el hiab, tienen cama baja, medidas de la plana): {{hoja:Servicio Gruas}}
```
(Las columnas que regresa `{{hoja_buscar:}}`, como `Calendar_ID`, nunca le llegan al cliente.)

### 2.8 `estado_caso` — «¿cómo va mi servicio?»

**HOY ✅** — cambio recomendado: hoy abre un caso nuevo en cada consulta (se midió: casos 01064 y 01065).
```
@ruta(estado_caso #tracking: dónde va mi grúa, cómo va mi servicio, ya tienen unidad asignada, cuál es mi caso): - -> @estado_ticket
```

### 2.9 Ruta por defecto
```
@ruta_por_defecto: solicitud_servicio
```

---

## 3. Secciones del prompt (lo que no es ruta)

```
[ROL]
Eres el agente de Grúas SSUSA. Atiendes solicitudes de transporte, grúas, hiab, planas y
renta de equipo de clientes de la industria petrolera en Ciudad del Carmen, Paraíso y Dos Bocas.

[ALCANCE POR RAMA]
disponibilidad_equipo: da los horarios del equipo nombrado; si no nombró equipo, pregunta cuál.
solicitud_servicio: junta los datos del servicio y abre el caso.
cotizacion: junta los datos para cotizar; no inventa precios.
confirmacion_servicio: registra la confirmación del cliente para que se programe.
asignacion_coordinador: registra la asignación y el folio; los datos de unidad los da logística.
seguimiento_cambios: mueve o cancela lo que el cliente cambie; siempre vale el último dato.
consulta_catalogo: responde dudas técnicas con la hoja.
estado_caso: dice cómo va el caso del cliente.

[DATOS A PEDIR]
Equipo (tipo y capacidad) · Origen · Destino · Fecha · Hora · Carga (qué es, peso, medidas) ·
Folio del cliente si lo tiene (NAV, OCI, DMX, LOAD) · Responsable en sitio.
Pide solo lo que falte, máximo 2 datos por mensaje.

[REGLAS]
- Una SOLICITUD pide disponibilidad o precio: no la des por confirmada. Solo «le confirmamos el
  servicio» o «favor de presentarse» es una CONFIRMACIÓN.
- Algunos servicios requieren pago por adelantado antes de programar la unidad: dilo cuando
  el cliente confirme, no antes.
- «Presentarse en» es el ORIGEN; «entregar en» es el DESTINO. No los inviertas.
- Si el cliente corrige un dato (medida, fecha, hora), vale siempre el último.
- «El día lunes» sin número es ambiguo: confirma la fecha («¿el lunes 28 de septiembre?»).
- Si el equipo que tenemos no cumple lo que piden (capacidad, extensiones, certificado), dilo
  y ofrece lo que sí tenemos. No digas que cumple si la hoja no lo muestra.
- Un dato solo es verdadero si lo dio el cliente o está en la hoja. No inventes precios,
  operadores, placas ni horarios.

[ETIQUETAS]
#disponibilidad = pidió horarios o disponibilidad de un equipo.
#solicita_servicio = pidió programar un servicio.
#solicita_cotizacion = pidió precio.
#confirmado = confirmó el servicio en firme.
#asignacion = un coordinador asignó el servicio a SSUSA.
#reprogramacion = cambió, canceló o corrigió un servicio.
#consulta_producto = duda técnica del equipo.
#tracking = preguntó cómo va su caso.

[ESTILO]
Cordial, breve, de tú. 2 a 4 líneas. Una o dos preguntas por mensaje.

[NO SIMULAR]
No digas «ya quedó programado» ni «te mando los datos del operador» si el sistema no lo hizo.
```

---

## 4. Conversaciones de ejemplo (las 26 del corpus)

Formato: lo que manda el cliente (resumido, sin correos ni teléfonos) → ruta → lo que responde el
agente **hoy** → lo que respondería **con motor completo**.

### Ejemplo 1 — Grúa 40 t · Baker Hughes · confirmar disponibilidad
```
👤 De su amable confirmación para la disponibilidad de la grúa 40 T, el domingo 2 de agosto
   a las 10:00 am, en base Baker Hughes.
🧭 disponibilidad_equipo
🤖 HOY: no encuentra «grúa 40 t» en la hoja (solo remolques) → pide el equipo o abre caso.
        Además el domingo no se trabaja: «El domingo no hay servicio…».
🤖 🔧:  busca grúas con capacidad ≥ 40 t, horario 24 h:
        «Para el domingo 2 a las 10:00 tengo libre la grúa GR-40A. ¿La aparto?»
        → evento TENTATIVO. En firme solo cuando confirme (ruta confirmacion_servicio).
```

### Ejemplo 2 — Grúa 80 t · OLAM Energy · cotización con ficha del equipo
```
👤 Cotización de grúa de 80 t para el día lunes a las 08:00, ~1 hora, carga de unidad
   inyectora 26 t (8.4 × 2.5 × 3.2 m) sobre cama baja. Patio OLAM Energy, Paraíso.
🧭 cotizacion
🤖 HOY: junta datos y abre caso Comercial. Si se agenda, dice la fecha completa: «Entiendo que
        es el lunes 28 de septiembre, a las 08:00. Está libre: 1️⃣ … Responde 1 para apartarlo»
        (pieza 6, 26/09) — no aparta en firme sin el «1».
🤖 🔧:  «¿El lunes 28 de septiembre a las 08:00?» → con 26 t confirma que 80 t alcanza →
        precio por hora desde «Tarifas» → caso Comercial con la ficha de la carga.
📎 La ubicación viene en un link de mapas y la ficha podría venir en PDF (🔧 adjuntos).
```

### Ejemplo 3 — 2 HIAB por jornada de 16 h · Cotemar
```
👤 Cotizar por jornada de 16 horas: HIAB 14–15 t con 5 extensiones y HIAB 12 t con 5
   extensiones, con certificados. KM 10.5 Prefabricado.
🧭 cotizacion
🤖 HOY: abre UN caso Comercial con los dos equipos en la descripción.
🤖 🔧:  compara contra «Equipos»: «Contamos con HIAB de 12 t con 4 extensiones; no tenemos de
        14–15 t ni con 5 extensiones. ¿Te cotizo la de 12 t?» → 1 caso por equipo (@solicitudes).
```

### Ejemplo 4 — HIAB 12 t · Sumerge Emerge · cotización → confirmación con hora exacta
```
👤 (27-jun) Cotización HIAB 12 t: contenedor de aluminio 3 × 1.20 m, 3 compresores, caja
   metálica. Carga martes 30 de junio 03:00 en Sumerge, destino puerto de Seybaplaya.
🧭 cotizacion → caso Comercial
👤 (29-jun) Solicito que el HIAB se presente el 30/06/2026 a las 03:00 en Sumerge km 14+500;
   el chofer se reporta con Almacén (Srta. Leydi…).
🧭 confirmacion_servicio
🤖 HOY: 03:00 está fuera de horario → no hay cita; abre caso con prioridad alta.
🤖 🔧:  evento en firme 03:00 en el calendario del HIAB asignado → pide pago previo si aplica →
        responde con los datos de la unidad desde «Unidades»:
        «Unidad: Torton c/hiab · TP-118 · Operador: … · Freightliner M2 2025 · Placas … · Blanco».
📄 Documentos que exige el cliente: póliza, licencia, tarjeta de circulación, credenciales.
```

### Ejemplo 5 — Torton c/hiab · Baker Hughes vía coordinador (On Call)
```
👤 Favor de asignar este servicio al proveedor SSUSA en modalidad On Call: NAV19602808.
   Favor de confirmar datos de unidad y operador. (Torton de 7 m)
🧭 asignacion_coordinador
🤖 HOY: caso Seguimiento interno con el folio NAV19602808 en la descripción.
🤖 🔧:  datos de la unidad asignada desde «Unidades» + folio como campo del caso.
```

### Ejemplo 6 — Programa multi-equipo recurrente · Blue Marine (3 correos)
```
👤 (28-may) Reitero: grúa 60 t + tracto con plana 12 m + camión con hiab, mañana 29 de mayo
   08:00, patio Pemex km 14+500 → patio Blue Giant. Necesitamos datos de personal y unidades
   para accesos Pemex.
👤 (30-may) Programa del 31 de mayo: 07:00 2 hiab 10–12 t en patio Blue Giant; 07:00 1 hiab 10 t
   en muelle 13; 1 grúa 60 t, ~1 hora.
👤 (30-may) Lunes 1 de junio: grúa 80 t 08:00 + plana 12 m, km 14+500 → Blue Giant.
🧭 solicitud_servicio (cada correo)
🤖 HOY: un solo caso para todo (reusa el abierto) y ninguna cita (no están en la hoja).
🤖 🔧:  @solicitudes separa 3 + 3 + 2 servicios → 1 caso y 1 evento tentativo por equipo;
        detecta que el del 28 es reiteración (mismo servicio, no duplicar).
```

### Ejemplo 7 — Plana · LOCIMAT · cotización + disponibilidad, carga química
```
👤 Cotizar plana del almacén en Cd. del Carmen a Base OPEX (API Dos Bocas), tentativo
   4 de agosto. 8 totes de 1,000 L MAXFLO, 8,800 kg en total.
🧭 cotizacion (y disponibilidad)
🤖 HOY: plataformas planas SÍ están en la hoja → puede dar horarios del 4 de agosto de una plana
        que aguante 8.8 t; abre caso Comercial para el precio.
🤖 🔧:  precio desde «Tarifas» + evento tentativo.
```

### Ejemplo 8 — Plana foránea · Corporativo Latina · tabla de datos
```
👤 Programar una plana a las 10:00 del lunes 01-jun, presentarse en la TMDB, entregar en
   almacén central Latina (Mundo Maya). Llenar la tabla: operador, económico tracto, placas
   tracto, año, modelo, marca, teléfono, económico remolque, placas remolque.
🧭 solicitud_servicio
🤖 HOY: horarios de una plana el lunes 01 a las 10:00 ✅ (en horario). No puede llenar la tabla.
🤖 🔧:  llena la tabla desde «Unidades» (hoja_buscar como fuente de datos).
⚠️ Origen = TMDB («presentarse en»); destino = Mundo Maya («entregar en»).
```

### Ejemplo 9 — Torton foráneo · Corporativo Latina · ruta inversa
```
👤 Programar un torton a las 03:00 del martes 26-may, presentarse en almacén Latina
   (Mundo Maya), entregar en la TMDB. Misma tabla.
🧭 solicitud_servicio
🤖 HOY: torton no está en la hoja y 03:00 está fuera de horario → caso.
🤖 🔧:  torton desde «Equipos», horario 24 h, tabla desde «Unidades».
⚠️ Mismo cliente que el 8 con origen y destino al revés.
```

### Ejemplo 10 — 2 fletes de maquinaria + horas de HIAB · MADISA (URGENTE)
```
👤 Cotizar por separado: (1) plataforma articulada Haulotte HA20, 9 × 2.5 × 3 m, 9,430 kg;
   (2) plataforma tijera Zoomlion, 2.5 × 1.85 × 2.8 m, 2,930 kg. Madisa Cd. Carmen → Megabase
   Baker Hughes, 1 de junio, 18:00–00:00. Más precio de horas de hiab para carga y descarga.
🧭 cotizacion
🤖 HOY: 1 caso Comercial con todo junto; 18:00–00:00 fuera de horario.
🤖 🔧:  @solicitudes → 2 casos (uno por equipo) + servicio adicional de hiab;
        duración = 6 h nocturnas; prioridad alta por «URGENTE».
```

### Ejemplo 11 — Pick up · Expro (solicitud numerada)
```
👤 DMX-26-393. SOLICITUD 01: 01 pick up, origen Base HLB Laguna Azul, destino Base Expro
   Laguna, 3 de agosto 11:00, retiro de equipos.
🧭 disponibilidad_equipo / solicitud_servicio
🤖 HOY: pick up no está en la hoja → caso con el folio en la descripción.
🤖 🔧:  1 evento por cada «SOLICITUD 0N»; folio DMX como campo.
```

### Ejemplo 12 — Unidad ligera · Expro
```
👤 DMX-26-391. SOLICITUD 01: 01 unidad ligera, Hotel Fiesta Inn CDC → Base HLB Puerto
   Pesquero, 2 de agosto 09:00, ingreso de equipo.
🧭 igual que el 11
💡 «Unidad ligera» = pick up para este cliente: ponlo como sinónimo en la hoja «Equipos»
   (columna `tipo` o `sinonimos`).
```

### Ejemplo 13 — Camión 350 · Baker Hughes Pressure Pumping
```
👤 Programar un camión 350 para mover materiales de EMCRO a UNIVAR Solutions. NAV19505095.
🧭 solicitud_servicio
🤖 HOY: caso con el folio; pregunta la fecha (no viene en el mensaje) ✅.
🤖 🔧:  además busca camión 350 en «Equipos».
```

### Ejemplo 14 — Tracto + remolque, viaje redondo · Baker Hughes
```
👤 Transporte de Pozo Madrefil 121 a Planta Linde y retorno al pozo. Tracto 80-BA-7F TP-101,
   remolque 22-UF-4L. NAV19531669, NAV19531905.
🧭 asignacion_coordinador (la unidad ya viene asignada)
🤖 HOY: caso con los dos folios.
🤖 🔧:  1 servicio con 2 tramos (ida y retorno) en el calendario de la TP-101.
```

### Ejemplo 15 — Quinta c/plana 15 m · Baker Hughes (On Call)
```
👤 Recolectar tramo TR de In Hole Solutions a TMDB a las 10:30. NAV18278527. Anexo CCP.
   Favor de asignar a SSUSA On Call y confirmar datos de unidad y operador.
🧭 asignacion_coordinador
🤖 HOY: caso con folio y hora.
🤖 🔧:  datos de unidad desde «Unidades»; carta porte como documento requerido.
```

### Ejemplo 16 — Tubería y magneto · OPEX · datos que cambian en el hilo
```
👤 Envío de un magneto hoy de base WTF Antimonio a Cd. del Carmen + 3 tramos de 20".
👤 (seguimiento) 3 tramos casing 20" 133# K55, 6,000 kg, medida 2 m → corregido a 10 m.
🧭 solicitud_servicio → seguimiento_cambios
🤖 HOY: caso; la regla «vale el último dato» hace que use 10 m.
🤖 🔧:  @solicitudes: 2 cargas en un mismo servicio.
```

### Ejemplo 17 — Grúa 110 t · DENCA · cotización multi-esquema
```
👤 Cotización de grúa 110 t, km 13 carretera Carmen–Puerto Real: renta por hora diurna y
   nocturna, jornada de 8 y 12 h diurna y nocturna, servicio de 24 h en dos jornadas.
🧭 cotizacion
🤖 HOY: caso Comercial (sin fecha → no se agenda, correcto).
🤖 🔧:  los 6 esquemas desde «Tarifas» (modo Datos).
```

### Ejemplo 18 — Renta 6 meses, 4 equipos · OTI
```
👤 Cotizar por 6 meses en Campeche: plataforma de elevación 120 ft, Titán 38 t, grúa 90 t,
   grúa 160 t. Incluir disponibilidad, precio, movilización, especificaciones, si incluye
   operador y combustible.
🧭 cotizacion
🤖 HOY: 1 caso «Renta Unidades».
🤖 🔧:  @solicitudes → 4 renglones; disponibilidad por periodo completo (bloquea 6 meses).
```

### Ejemplo 19 — Renta + transporte ida y vuelta · ARBAMEX
```
👤 Cotizar renta de rack, toolbox, máquinas de soldar y 1 transporte de entrega y
   recolección Carmen – Villahermosa – Carmen. Enviar fotos y fichas técnicas.
🧭 cotizacion
🤖 HOY: caso «Renta Unidades».
🤖 🔧:  «entrega y recolección» = 2 movimientos separados (inicio y fin de la renta).
📎 Fotos y fichas: se pueden cargar como archivos del agente y mandarse con {{nombre_del_archivo}} ✅.
```

### Ejemplo 20 — Rabón c/grúa · ARBAMEX · cotización → confirmación
```
👤 Cotizar 7 secciones de barandales de Cunduacán a puerto de Veracruz, rabón con grúa
   mínima de 3 t, mañana 8 am.
🧭 cotizacion
👤 (mismo día) Le confirmamos el servicio. Favor de presentarse mañana 8 am en el patio de ARBA.
🧭 confirmacion_servicio
🤖 HOY: caso; la confirmación abre caso de prioridad alta para que se programe.
🤖 🔧:  el primer mensaje aparta (tentativo); el segundo lo pasa a en firme.
```

### Ejemplo 21 — Traslado de contenedor · ATLAS E&C
```
👤 Cotización para trasladar un contenedor del patio SSUSA en Paraíso al muelle Pemex TMDB.
🧭 cotizacion
🤖 HOY: pide fecha y datos del contenedor → caso Comercial ✅.
🤖 regla: «este servicio requiere pago por adelantado» al confirmar.
```

### Ejemplo 22 — Tracto + plana 14 m con grúa · WIS
```
👤 Cotizar tracto con plana de 14 m con grúa, Villahermosa → Tampico (sistema de 13").
🧭 cotizacion
🤖 HOY: pide fecha y peso (no vienen) → caso Comercial ✅.
```

### Ejemplo 23 — Grúa 80 t diurno y nocturno · Operadora CICSA (requisición)
```
👤 OCI747255. Cotizar lo adjunto (PDF). 2 días para responder. Incluir fichas técnicas.
   Responder sobre el mismo correo sin cambiar el asunto. Entrega en almacén CDC.
🧭 cotizacion
🤖 HOY: caso con folio OCI y plazo; no lee el PDF.
🤖 🔧:  leer la requisición adjunta; folio OCI como campo; vencimiento del caso a 2 días.
```

### Ejemplo 24 — Cama baja vía RFQ · Subtec Procurement
```
👤 Cotizar la REQ anexa, prioridad alta, 1 día para responder, certificados obligatorios.
   Entrega en BME Subtec km 13.8 Carretera Carmen–Puerto Real.
👤 (día siguiente) ¿Qué disponibilidad tienen para que el servicio se realice mañana?
🧭 cotizacion → disponibilidad_equipo
🤖 HOY: caso; al preguntar «mañana», da horarios de una cama baja de la hoja ✅.
🤖 🔧:  leer la RFQ adjunta.
```

### Ejemplo 25 — Consolidación y cambio de modalidad · Baker Hughes
```
👤 Consolidar: NAV19606150 Base Baker CDC → Base Expro; NAV19610449 Base Expro → muelle TMDB.
   Mantener a SSUSA. Cambiar la modalidad a Renta Mensual.
🧭 asignacion_coordinador
🤖 HOY: caso con los 2 folios.
🤖 🔧:  1 servicio con 2 paradas (no 2 servicios); modalidad como campo del caso.
```

### Ejemplo 26 — Renta mensual, retiro de herramientas · Baker Hughes
```
👤 Asignar a SSUSA en renta mensual: 4-ago-26, TMDB → Base CME, NAV19606421, quinta.
🧭 asignacion_coordinador
🤖 HOY: caso con folio.
🤖 🔧:  responde como SSUSA responde hoy:
        «Comparto datos de operador y unidad para accesos a la TMDB:
         Unidad: TP-60 · Freightliner M2 2022 · Operador: … · Tracto con cama baja ·
         Placas 82AU1W · Plataforma 33UL2B · Blanco».
```

### Resumen por ejemplo

| Resultado | Ejemplos |
|---|---|
| ✅ Hoy se resuelve (horarios o caso completo) | 7, 8 (entre semana), 13, 21, 22, 24 (2º mensaje) |
| 🟡 Hoy abre caso para un asesor | 1–6, 9–12, 14–20, 23, 25, 26 |
| 🔧 Resuelto de punta a punta con motor completo | los 26 (18 y 23 con adjuntos y periodos largos) |

---

## 5. Cómo pedírselo al Asistente

### 5.1 Antes de empezar (checklist)
- [ ] Hojas «Equipos», «Unidades» y «Tarifas» creadas y sincronizadas (o, para empezar, solo la actual «Servicio Gruas»).
- [ ] Tipo de caso «Solicitud de transporte» con sus campos obligatorios.
- [ ] Calendarios de cada equipo marcados en la agenda del agente.

### 5.2 Abrir el agente en el Asistente
1. **Agentes IA → Asistente**, pestaña de agentes → fila **«Agente de Grúas SSUSA»** → **Nueva versión**
   (trabaja sobre una copia; el agente en producción no cambia hasta que guardes).
2. Panel izquierdo en **Chat**.

### 5.3 Mensaje 1 — las rutas (copia y pega) ✅ HOY
> Solo usa directivas que ya existen. Las de la sección 2 marcadas 🔧 NO se incluyen.

```
Reorganiza las rutas de este agente. Recibe solicitudes de clientes de la industria petrolera
(grúas, hiab, planas, torton) y necesito estas 8 rutas, con estas frases del cliente, fuente y
acción EXACTAS:

1. disponibilidad_equipo #disponibilidad
   Frases: qué disponibilidad tiene la TP-64, cuándo está libre un remolque, de su amable
   confirmación para la disponibilidad de, confirmando la disponibilidad de, disponibilidad
   para mañana, quiero agendar un remolque
   Fuente: ninguna (-)
   Acción: {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar

2. solicitud_servicio #solicita_servicio
   Frases: solicito su apoyo para programar una unidad, requerimos programar un camión, su
   apoyo con la gestión de la siguiente solicitud, favor de programar una plana, transporte de
   materiales de, flete de maquinaria
   Fuente: {{hoja:Servicio Gruas}}
   Acción: @crear_ticket(tipo=Comercial, prioridad=media)

3. cotizacion #solicita_cotizacion
   Frases: me podrían cotizar, solicito cotización, favor de cotizar por jornada, cuánto
   cuesta, renta por hora, renta mensual, propuesta económica
   Fuente: {{hoja:Servicio Gruas}}
   Acción: @crear_ticket(tipo=Comercial, prioridad=media)

4. confirmacion_servicio #confirmado
   Frases: le confirmamos el servicio, favor de presentarse mañana, solicito que el servicio
   se presente el día, queda confirmado
   Fuente: ninguna (-)
   Acción: @crear_ticket(tipo=Comercial, prioridad=alta)

5. asignacion_coordinador #asignacion
   Frases: favor de asignar este servicio al proveedor SSUSA, modalidad On Call, favor de
   confirmar datos de unidad y operador, consolidar este servicio
   Fuente: ninguna (-)
   Acción: @crear_ticket(tipo=Seguimiento interno, prioridad=alta)

6. seguimiento_cambios #reprogramacion
   Frases: vamos a reprogramar, cambio operativo, la entrega no se podrá realizar, cambiar la
   fecha, cancelar el servicio, se corrige la medida
   Fuente: ninguna (-)
   Acción: @agendar_calendar

7. consulta_catalogo #consulta_producto
   Frases: qué tipos de grúas manejan, qué capacidad tiene la TP-64, cuántas extensiones tiene
   el hiab, medidas de la plana
   Fuente: {{hoja:Servicio Gruas}}
   Acción: ninguna

8. estado_caso #tracking
   Frases: dónde va mi grúa, cómo va mi servicio, ya tienen unidad asignada
   Fuente: ninguna (-)
   Acción: @estado_ticket

Ruta por defecto: solicitud_servicio.
Quita las rutas disponibilidad_remolque, consulta_estado_caso e info_recurso_agendado: las
reemplazan disponibilidad_equipo, estado_caso y seguimiento_cambios.
No inventes directivas que no estén en los recursos de la cuenta.
```

### 5.4 Mensaje 2 — las secciones ✅ HOY
```
Ahora reescribe las secciones con esto:
- [ALCANCE POR RAMA]: una línea por cada una de las 8 rutas, diciendo qué hace.
- [DATOS A PEDIR]: equipo (tipo y capacidad), origen, destino, fecha, hora, carga (qué es,
  peso, medidas), folio del cliente si lo tiene (NAV, OCI, DMX, LOAD), responsable en sitio.
  Solo lo que falte, máximo 2 por mensaje.
- [REGLAS]:
  · una solicitud pide disponibilidad o precio; solo «le confirmamos el servicio» o «favor de
    presentarse» es confirmación;
  · algunos servicios requieren pago por adelantado: dilo cuando el cliente confirme;
  · «presentarse en» es el origen y «entregar en» es el destino;
  · si el cliente corrige un dato, vale el último;
  · «el día lunes» sin número: confirma la fecha;
  · si el equipo no cumple lo pedido (capacidad, extensiones, certificado), dilo y ofrece lo
    que sí hay;
  · no inventes precios, operadores, placas ni horarios.
- [ETIQUETAS]: una línea por etiqueta de las rutas, qué significa cada una.
- [ESTILO]: cordial, breve, de tú, 2 a 4 líneas.
Deja [ROL] como está pero agrega que atiende clientes de la industria petrolera en Ciudad del
Carmen, Paraíso y Dos Bocas.
```

### 5.5 Mensaje 3 — revisar ✅ HOY
```
Analiza el prompt
```
- El comprobador pinta cada línea con problema (pasa el mouse para ver el aviso).
- Si sale **«la etiqueta no existe»**: botón **«Crearla»** en el aviso o en «Editar ruta».
- Si ofrece **«Sí, corrige lo que se puede en el texto»**, úsalo y vuelve a analizar.
- **Guardar** cuando no quede nada en rojo.

Resultado medido con el comprobador sobre estas 8 rutas (26/09/2026): **0 en rojo**, y en ámbar:
- 4 × «la etiqueta no existe» (`#disponibilidad`, `#confirmado`, `#asignacion`, `#reprogramacion`) → **Crearla**;
- «hay rutas con acción y rutas sin ella» (`consulta_catalogo`): esperado, no impide guardar.

### 5.6 Alternativa sin chat: por la Estructura ✅ HOY
Estructura → **Rutas** → **Agregar ruta**, una por una:

| Campo del formulario | Qué poner |
|---|---|
| Nombre | `disponibilidad_equipo` |
| Etiqueta | `#disponibilidad` (si no existe: **Crearla**) |
| Frases del cliente | las de la sección 2 |
| De dónde saca la respuesta | «No consulta nada» |
| Si no resuelve | `@agendar_calendar` |
| Qué atiende esta ruta | botón **Generar** (la escribe desde las frases) |

⚠️ «Si no resuelve» es una lista y no deja escribir `{{hoja_buscar:}}`. Después de guardar la
ruta, en el **editor del Entrenamiento** (panel derecho) agrega la directiva en esa línea,
antes de `@agendar_calendar`:
```
… ): - -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```
Las demás rutas se arman completas con el formulario.

### 5.7 Probar
En el chat del Asistente pega el link de una conversación de prueba de **Agents IA Test**
(`…/conversations/N`) y pregunta qué respondió mal y por qué. Frases para probar, una por
conversación nueva:

| Frase | Ruta esperada | Resultado esperado hoy |
|---|---|---|
| ¿Qué disponibilidad tiene la TP-93 para el martes? | disponibilidad_equipo | horarios del martes de la TP-93 |
| Quiero agendar un remolque | disponibilidad_equipo | «¿Para cuál remolque…?» |
| Favor de programar una plana el lunes 10:00, presentarse en TMDB, entregar en Mundo Maya | solicitud_servicio | pide lo que falte y abre caso |
| Me podrían cotizar una grúa de 110 t por jornada de 12 h | cotizacion | caso Comercial, sin inventar precio |
| Le confirmamos el servicio, favor de presentarse mañana 8 am | confirmacion_servicio | caso prioridad alta |
| Favor de asignar a SSUSA On Call NAV19602808 | asignacion_coordinador | caso con el folio |
| Vamos a reprogramar la entrega | seguimiento_cambios | mueve la cita |
| ¿Qué capacidad tiene la TP-64? | consulta_catalogo | 60 t, sin links de calendario |
| ¿Cómo va mi servicio? | estado_caso | estado del caso, sin abrir uno nuevo |

### 5.8 Qué NO pedirle todavía 🔧
Esta directiva **no existe**; si el Asistente la escribe, el motor la ignora:

```
@solicitudes
```
Desde el 26/09 SÍ existen (ver la bitácora, sección 7): comparaciones en `{{hoja_buscar:}}`,
`{{hoja_buscar:}}` como fuente de datos, `@agendar_calendar(duracion=?, horario=24h, modo=tentativo)`
y `@confirmar_servicio(requiere=pago)`.

---

## 6. Lo que le falta al motor (para después)

| # | Pieza | Tamaño | Ejemplos que destraba |
|---|---|---|---|
| 1 | ✅ HECHA 26/09 — `{{hoja_buscar:}}` con `>=`, `<=`, `!=` y números leídos de la conversación | chico | 1, 2, 3, 6, 17, 20, 22, 23 |
| 2 | ✅ HECHA 26/09 — `{{hoja_buscar:}}` como fuente de datos para la respuesta | chico | 4, 5, 8, 9, 15, 26 |
| 6 | ✅ HECHA 26/09 — Confirmar fechas ambiguas («el día lunes») | chico | 2 |
| 3 | ✅ HECHA 26/09 — `@agendar_calendar(duracion=?, horario=24h)` (tope 24 h; rentas largas pendientes) | mediano | 1, 2, 3, 4, 9, 10, 17 |
| 4 | ✅ HECHA 26/09 — `modo=tentativo` + `@confirmar_servicio(requiere=pago)` + etiqueta `pago_confirmado` | mediano | 4, 20, 21, 24 |
| 5 | `@solicitudes`: un caso y una cita por servicio | **grande** | 3, 6, 10, 11, 14, 16, 18, 19, 25 |
| 7 | Leer PDF / Excel adjuntos · probar en canal de correo | mediano | 2, 8, 10, 23, 24 · los 26 |

Orden recomendado: **1 → 2 → 6 → 3 → 4 → 5 → 7**. Con 1–4 más las hojas, los servicios de un
solo equipo quedan resueltos de punta a punta; 5 cubre los correos con varias solicitudes.

---

## 7. Bitácora por fase (qué se hizo · cómo funciona · pruebas · cómo pedírselo al Asistente)

> Todas las pruebas se hicieron en **Agents IA Test** (canal 493) con la copia de prueba
> **#10368 «Grúas SSUSA — prueba hoja_buscar»**, salvo donde dice #10238 (el agente real).
> Los calendarios de la agenda 178 (camion01kontrolya@gmail.com) son **de prueba**.
> Rama: `feat/hoja_buscar`. Plan técnico: `docs/hoja_buscar_plan.md`.

### Fase A — `{{hoja_buscar:}}`: el calendario del remolque nombrado (25/09)

**Qué se hizo.** Directiva nueva que busca exacto en la hoja (sin IA) y regresa otra columna.
Después de la flecha alimenta la agenda: los horarios salen SOLO del calendario de lo que se
nombró. La hoja guarda sus filas tal cual también en modo FAQ. El comprobador y el catálogo la
conocen.

**Cómo funciona.**
```
{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}
               └── la hoja ──┘ └─ buscar ─┘ └─ regresar ─┘
«?» = lo que se nombró en los últimos mensajes (lo del cliente gana; si no, lo que ofreció el agente)
```
Si no se nombró ninguno: «¿Para cuál remolque quieres agendar?».

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 219 | Me interesa la TP-64, ¿qué horarios tiene? | horarios del calendario TP-64 ✅ |
| 220 | Quiero agendar un servicio de remolque | «¿Para cuál remolque…?» ✅ |
| 221 | excavadora → agente recomienda TP-93 → «agéndame en la que me recomiendes» | calendario TP-93 ✅ |
| 222 | Quiero agendar la TP-63 → 1 → sin correo | cita creada en calendario TP-63 ✅ |

**Cómo pedírselo al Asistente.**
```
En la ruta disponibilidad_remolque, que no consulte ninguna fuente y que después de la flecha
diga exactamente: {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```

### Fase B — Ruta de disponibilidad y arreglos de agenda (25/09)

**Qué se hizo.**
1. Una ruta **sin fuente** con `{{hoja_buscar:}} -> @agendar_calendar` es «de disponibilidad»:
   va directo a horarios (antes la IA de citas a veces decía «plática» y contestaba con la hoja).
2. Si el día pedido no se ofrece, se dice por qué: «Mañana sábado no hay servicio…» (día no
   laboral) o «Para mañana ya no tengo horarios…» (lleno).
3. Las columnas que regresa una `{{hoja_buscar:}}` de agenda (`Calendar_ID`) ya no le llegan al
   cliente por `{{hoja:}}` (antes se filtraron los links de los calendarios).
4. «¿Y en la tarde?» busca en la tarde del día ofrecido (antes repetía la mañana).
5. Con horarios ofrecidos, nombrar otro remolque («¿y la TP-58?») o preguntar «¿cuándo está
   libre?» vuelve a buscar (antes repetía la oferta anterior).
6. «Presentación de horarios = por calendario» en el agente: cada horario dice su remolque.

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 227–229 | ¿horarios de TP-64 y TP-63 para mañana? (×3) | las 3 iguales: «Mañana sábado no hay servicio… lunes 28» ✅ |
| 231 | ¿Qué capacidad tiene la TP-64? | 60 t, sin links ✅ |
| 234 | TP-93 el martes → «¿y en la tarde?» → «¿cuándo está libre la TP-58?» | martes 9–11 → martes 12–14:30 → TP-58 lunes ✅ |
| 234–235 | cita TP-64 lun 28 09:30 → otro cliente pregunta ese horario | «Uy, ese horario no está disponible» ✅ |

**Cómo pedírselo al Asistente.**
```
Agrega una ruta disponibilidad_remolque con frases como: qué horarios tiene la TP-64, cuándo
está libre un remolque, disponibilidad para mañana, quiero agendar un remolque. Sin fuente, y
después de la flecha: {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar
```
(La presentación «por calendario» se elige en la ficha del agente, no en el prompt.)

### Pieza 1 — Comparaciones en `{{hoja_buscar:}}` (26/09)

**Qué se hizo.** `>=`, `<=`, `>`, `<` con números y `!=` con textos. Con `?`, el número sale del
mensaje del cliente **con su unidad** (t, ton, toneladas, kg ÷ 1000; m, mts, metros; o la palabra
de la columna: «5 extensiones»). Fechas y horas no cuentan. Con dos números y `>=`, el mayor.
Textos sin acentos («grua» = «Grúa»).

**Cómo funciona.**
```
{{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}}
«grúa de 80 toneladas para una carga de 26 t» → capacidad_t >= 80
```

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 247 | remolque para 50 toneladas | solo TP-64 (60 t) ✅ |
| 249 | carga de 8,800 kg | 8.8 t → todos califican, horarios repartidos ✅ |

**Cómo pedírselo al Asistente.**
```
En la ruta disponibilidad_equipo, después de la flecha escribe exactamente:
{{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}} -> @agendar_calendar
```

### Pieza 2 — `{{hoja_buscar:}}` como fuente de datos (26/09)

**Qué se hizo.** Antes de la flecha (como FUENTE) responde con las filas exactas; el modelo solo
redacta. Si no nombró el valor, pregunta cuál; si no existe, lo dice sin inventar. Como fuente
nunca decide calendarios.

**Cómo funciona.**
```
@ruta(asignacion_coordinador …): {{hoja_buscar: Unidades | economico=? | operador, telefono, placas_tracto, color}} -> @crear_ticket(...)
```

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 248 | ¿Qué placas tiene la TP-63 y qué tracto la jala? | «placas 92UN8A, tracto TP-55» (exacto) ✅ |

**Cómo pedírselo al Asistente.**
```
Agrega la ruta datos_remolque con frases: qué placas tiene la TP-63, dame los datos de la TP-64,
qué tracto jala la TP-93. Como FUENTE (antes de la flecha) pon exactamente:
{{hoja_buscar: Servicio Gruas | remolque=? | tipo, placas, peso_max_t, jalado_por}}
```

### Pieza 6 — «El día lunes» sin número (26/09)

**Qué se hizo.** Día de la semana sin número = ambiguo (sin IA). El agente dice la fecha completa;
con hora libre la ofrece como opción 1 en vez de apartarla directo.

**Pruebas.**
| Conv | Cliente | Resultado | Cita |
|---|---|---|---|
| 250 | TP-64 el lunes a las 12:00 | «Entiendo que es el lunes 28 de septiembre, a las 12:00. Está libre: 1️⃣ … Responde 1 para apartarlo» | no ✅ |
| 251 | TP-63 el día martes | «Entiendo que es el martes 29 de septiembre. Estos son los horarios de ese día…» | no ✅ |

**Cómo pedírselo al Asistente.** No hace falta: lo hace el motor en toda ruta que agenda.

### Pieza 3 — Duración del servicio y horario 24 h (26/09)

**Qué se hizo.** `@agendar_calendar(duracion=?, horario=24h)`. `duracion=?` se lee del mensaje
(«una hora», «jornada de 16 horas», «6:00 pm – 12:00 am», «2 hrs»; tope 24 h); `duracion=90` o
`duracion=2h` fija; `horario=24h` = cualquier hora de cualquier día. Servicios largos se ofrecen
cada hora. Arreglo encontrado al probar: «domingo 4 de octubre» daba el domingo 27.

**Pruebas.**
| Conv | Cliente | Resultado |
|---|---|---|
| 254 | TP-64 domingo 4 de octubre, jornada de 16 horas | dom 4 oct 00:00–16:00, 01:00–17:00… ✅ |
| 253 | TP-93 el 5 de octubre, 6:00 pm – 12:00 am | aparta 18:00–00:00 (6 h) ✅ |

**Cómo pedírselo al Asistente.**
```
En la ruta disponibilidad_equipo cambia la acción final por exactamente:
@agendar_calendar(duracion=?, horario=24h)
```

### Pieza 4 — Apartado → confirmado (con pago) (26/09)

**Qué se hizo.** `@agendar_calendar(modo=tentativo)` aparta el horario («[TENTATIVO]» en el
calendario; ocupa el horario). `@confirmar_servicio` en la ruta de confirmación lo deja en firme;
con `(requiere=pago)` pide el pago y queda en firme cuando una persona pone la etiqueta
**`pago_confirmado`** (el cliente recibe «✅ Recibimos tu pago…»). El comprobador avisa si falta
la etiqueta y ofrece «Crearla». Nuevo en la base: `contact_trackings.appointment_status`
(tentative → pending_payment → confirmed).

**Cómo funciona.**
```
👤 ¿Qué disponibilidad tiene la TP-64 el lunes 5 de octubre a las 10:00? El servicio dura 2 horas.
🤖 ¿A qué correo te envío la invitación…?            👤 sin correo
🤖 📌 Te aparté el lunes 5 de octubre de 2026 a las 10:00 – 12:00 hs. Queda *pendiente de confirmar*…
      calendario TP-64: «[TENTATIVO] Cita con …» 10:00–12:00
👤 Le confirmamos el servicio, favor de presentarse a las 10:00
🤖 ¡Gracias por confirmar! Para dejar en firme tu servicio… necesitamos el pago por adelantado…
      nota al equipo: «falta el pago. Al recibirlo, pon la etiqueta pago_confirmado»
   (el equipo pone la etiqueta pago_confirmado)
🤖 ✅ Recibimos tu pago. Tu servicio del lunes 5 de octubre a las 10:00 quedó confirmado.
      calendario TP-64: «Cita con …» (ya sin [TENTATIVO])
```

**Pruebas.**
| Conv | Paso | Resultado |
|---|---|---|
| 255 | pedir horario con fecha, hora y duración | apartado [TENTATIVO] 10:00–12:00 ✅ |
| 255 | «le confirmamos el servicio» | pide pago + nota; estado pending_payment ✅ |
| 255 | etiqueta `pago_confirmado` | en firme, aviso al cliente, estado confirmed ✅ |

**Cómo pedírselo al Asistente.**
```
1) En la ruta disponibilidad_equipo la acción final debe ser exactamente:
   @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
2) Agrega la ruta confirmacion_servicio #confirmado con frases: le confirmamos el servicio,
   favor de presentarse mañana, solicito que el servicio se presente el día, queda confirmado.
   Sin fuente, y después de la flecha: @confirmar_servicio(requiere=pago)
3) En [REGLAS]: «Un horario apartado queda pendiente hasta que el cliente confirme; si pide el
   pago, no digas que está confirmado hasta recibirlo.»
```
Después: «Analiza el prompt» → si avisa «#pago_confirmado no existe», botón **Crearla**.

### Pieza 5 — `@solicitudes`: varios servicios en una conversación (26/09, en curso)

Plan y bitácora completa: `docs/solicitudes_multiservicio_plan.md` §13. Hecho: F0 (Tarea agendada
tentativa en el calendario del equipo), F1 (separar el mensaje en servicios, 12/12 ejemplos del
corpus), F2 (un caso por servicio + reiteraciones), F3 (horarios 1A/2B por servicio y apartado),
F4 (confirmar/cancelar/mover por servicio; pago con etiqueta = todos o columna «Pagado» = uno).
Pruebas en vivo: conversaciones 256–259. Falta: F5 (comprobador/catálogo), F7 (rentas de días/meses).

**Cómo pedírselo al Asistente (lo que ya funciona):**
```
En la ruta solicitud_servicio, después de la flecha y en este orden exacto:
@solicitudes -> @crear_ticket(tipo=Solicitud de transporte, prioridad=media)
-> @agendar_calendar(duracion=?, horario=24h, modo=tentativo)
-> {{hoja_buscar: Equipos | tipo=?; capacidad_t>=? | Calendar_ID}}
Frases: solicito programar unidades, favor de programar las siguientes unidades, unidades
requeridas, SOLICITUD 01, solicito cotizar un flete.
```

**Confirmación con pago (F4):**
```
Agrega la ruta confirmacion_servicio #confirmado con frases: le confirmamos el servicio, le
confirmamos los servicios, confirmo el 1, favor de presentarse mañana. Sin fuente, y después de
la flecha: @confirmar_servicio(requiere=pago)
```
