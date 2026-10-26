# Plan · Mensaje de servicios y horarios de @solicitudes

> Rama: `fix/observaciones` (desde `develop` 742a66a6) · Agente: Grúas SSUSA · Kontrolya
> Origen: observaciones del cliente (22/10/2026) · Plan: 26/10/2026 · **Estado: solo plan, sin código**

---

## 1. El problema (lo que reporta SSUSA)

1. **El mensaje no se entiende.** Mezcla íconos, estados y datos en renglones que cada celular corta
   distinto. La unidad sale con nombres de columna («Peso max t: 40 · Largo m: 16.15»).
2. **No acepta respuestas naturales.** Pide «1A», «3B». El cliente escribió «Adelante con el horario»
   y el bot repitió la propuesta. Con el horario libre muestra una sola opción y el cliente siente
   que lo obligan a contestar algo específico.
3. **Falta el contacto del operador** asignado al servicio.

Ejemplo real:

```
Actualicé 1 servicio que ya tenía:
1️⃣ Rabón · Carmen → Villahermosa · mié 21 oct 12:00 (caso UNI-00029)
   ℹ️ No tengo rabón; lo más parecido que tengo:
   🚛 TP-46: Cama baja (piso bajo, para carga alta) · Peso max t: 40 · Largo m: 16.15 · Placas: 94UF4L
   sí hay a las 12:00 → 1A 12:00–13:00 (TP-46)
Responde con los horarios que quieres apartar (por ejemplo «1A y 3B»), o «sí» para la primera opción de cada uno.

Cliente: «Adelante con el horario»  →  el bot repite la propuesta
```

---

## 2. Diagnóstico: por qué pasa cada cosa

```
 mensaje del cliente
        │
        ▼
 ┌──────────────┐   ¿hay ofertas abiertas?   ┌──────────────────────────────┐
 │   Choice     │──────── sí ───────────────▶│ patrones fijos:               │
 │ (choice.rb)  │                            │  CODE_RE  «1A»                │
 └──────┬───────┘                            │  YES_RE   sí|ok|va|claro|dale │
        │ no coincide → nil                  │           |de acuerdo|aparta  │
        ▼                                    │           |todos|perfecto     │
 ┌──────────────┐                            │  «adelante» NO está  ✗        │
 │    Turn      │  Extractor (IA) → Registry └──────────────────────────────┘
 │  (turn.rb)   │  → Scheduler → reply()  ⇒  vuelve a mandar la propuesta
 └──────────────┘
```

| Síntoma | Causa | Dónde |
|---|---|---|
| «Adelante con el horario» no aparta | `YES_RE` no incluye «adelante» ni «confirmo»; la elección es por patrones, no por IA | `service_requests/choice.rb:16` |
| Una sola opción | Con la hora pedida libre, el Scheduler ofrece solo esa. Normalmente Turn la aparta directo (obs. SSUSA 5); aquí no, porque era un sustituto (`related`), y quedó una «1A» suelta | `scheduler.rb:136`, `turn.rb:114` (`hold_if_exact`) |
| Cama baja 40 t por un rabón | Sin el tipo pedido, vuelve a buscar sin los filtros de texto y solo con los de número: todo lo que aguanta la carga es «lo más parecido» | `scheduler.rb:66` (`related_spec`) |
| «Peso max t: 40 · Placas: …» | La unidad se describe con el nombre de cada columna que pide `{{hoja_buscar:}}`; las placas salen porque la ruta las pide | `scheduler.rb:213` (`describe_unit`) |
| Formato revuelto | Todo el texto se arma en `reply`, `line`, `options_line`, con emojis y números con emoji | `turn.rb` |
| Telegram rompería un bloque ``` | `Channel::Telegram#convert_markdown_to_telegram_html` cambia `\n` por `<br>` **antes** de CommonMarker, así que el bloque de código no se reconoce | `app/models/channel/telegram.rb:117` |

Hoja «Servicio Gruas» (cuenta 2, 24 filas). Columnas: `anio, base, tipo, marca, serie, placas,
ancho_m, largo_m, remolque, clase_sct, propiedad, jalado_por, peso_max_t, Calendar_ID, fuente_medidas,
estatus_contable, estatus_operativo`. **No hay columna de familia ni operador, y no hay ningún rabón.**

---

## 3. Cómo debe quedar el mensaje

```
Tu solicitud tiene 1 servicio:

*Servicio 1* · Carmen → Villahermosa
Cama baja · 40 t · 16.15 m
mié 21 oct · Caso UNI-00029
Estado: Por confirmar  (la de las 12:00 es la que pediste)
```
````
```
Op  Horario      Unidad
A   12:00-13:00  TP-46
B   14:00-15:00  TP-46
C   16:00-17:00  TP-73
```
````
```
Falta: ubicación de destino

Responde «sí» para apartar la opción A de cada servicio, o dime cuál prefieres
(por ejemplo «la de las 14:00» o «1B»).
```

Reglas:

- Bloque monoespaciado **según el canal**: WhatsApp ``` · Telegram `<pre>` · otros: una opción por renglón, sin bloque.
- Ancho máximo del bloque: **30 caracteres**. Sin íconos dentro del bloque.
- Unidad con etiquetas legibles (`peso_max_t` → «40 t», `largo_m` → «16.15 m»). **Nunca placas ni serie**, aunque la ruta las pida.
- Estados fijos, uno por servicio y en su propio renglón: **Por confirmar · Apartado · Confirmado · Esperando pago · Cancelado**.
- Lo que falta va dentro del bloque de cada servicio, no en un párrafo aparte.
- Un servicio confirmado no lleva tabla de opciones.
- Encabezado «Tu solicitud tiene N servicios:», en lugar de «Actualicé…/Recibí…».

---

## 4. Fases

```
 F1 Respuestas naturales ──┐
                           ├──▶ F3 Formato ──▶ F4 Operador ──▶ F5 Pruebas
 F2 Opciones y sustitutos ─┘
```

### F1 · Aceptar respuestas naturales (`choice.rb`)

La IA interpreta la respuesta. Recibe las ofertas abiertas y devuelve JSON: `{elegidos:[{servicio, codigo}], accion}`.
Usa la misma llamada que el Extractor (clave OpenAI de la cuenta, `EngineConfig.model_for_tracking`).
Si la IA no responde, quedan los patrones de hoy, con `YES_RE` ampliado (adelante, confirmo, va, perfecto…).

| Situación | Lo que escribe el cliente | Qué hace el bot |
|---|---|---|
| Una opción por servicio | «sí», «adelante», «ok», «confirmo», «adelante con el horario» | Toma esa opción en todos |
| Varias opciones | Afirmación genérica | Toma la A de cada servicio y lo dice |
| Varias opciones | «la de las 14», «la TP-73», «la B» (un servicio) | Toma la que coincide |
| Varios servicios | «el 2 a las 16», «1B y 2A» | Toma lo indicado; los demás quedan pendientes |
| Ambigua | «sí pero más tarde», «el otro» | Una sola pregunta con opciones cerradas |
| Rechazo | «ninguna», «no me sirve» | Pide otra fecha u hora |

Apartar vs. confirmar: si con lo apartado ya están todos los datos obligatorios, el mismo mensaje
pregunta «¿Confirmo el servicio?». Un segundo «sí» lo deja en firme vía `@confirmar_servicio`.

**Criterio:** con el ejemplo real, «Adelante con el horario» aparta 12:00–13:00 en TP-46 y responde con el bloque en estado Apartado.

### F2 · Cuántas opciones y qué sustituto (`scheduler.rb`, `turn.rb`)

- Hasta **3 opciones**: la hora pedida (si está libre) como A, marcada «la que pediste», más las 2 siguientes libres.
- Si ninguna cae el mismo día: «No hay horario el miércoles; lo más cercano es…».
- Las opciones pueden ser de unidades distintas si todas cumplen la carga.
- **Sustituto:** solo de la **misma familia** y con `peso_max_t ≥ carga`. Si no hay: «No tenemos rabón disponible» y se ofrece un asesor. Se dejan de inventar equivalencias.

```
 ¿hay el tipo pedido? ── sí ──▶ opciones de ese tipo
        │ no
        ▼
 ¿misma familia y peso_max_t ≥ carga? ── sí ──▶ ofrecer como sustituto
        │ no
        ▼
 «No tenemos <tipo> disponible» + ofrecer asesor
```

### F3 · Formato (`turn.rb`, `choice.rb`, `channel/telegram.rb`)

- Nuevo render por bloque de servicio (sección 3). El canal se toma de `conversation.inbox.channel_type`.
- `describe_unit` con sufijos por columna (`_t` → «t», `_m` → «m») y lista negra fija: `placas, serie, tracto`.
- Telegram: arreglar `convert_markdown_to_telegram_html` para que respete los bloques ``` (o mandar `<pre>` directo).
- La respuesta de Choice (lo apartado) usa el mismo bloque.

### F4 · Contacto del operador

- Hoja: columnas `operador_nombre` y `operador_telefono` (con lada, por ejemplo 9381234567).
- Se lee de la fila de la unidad apartada; si está vacía, de la fila de su tracto (`jalado_por`). Ver D4.
- **Solo cuando el servicio queda Confirmado.** Nunca en la propuesta ni en el apartado.
- Al final del bloque: «Operador: Juan Pérez», y el «Tel: 938 123 4567» **fuera** del bloque, para poder tocarlo y llamar.
- Celda vacía: «Te compartimos el contacto del operador en cuanto quede asignado». No se inventa nada.
- Se copia nombre y teléfono a campos del caso (registro de quién atendió).

### F5 · Pruebas (ver sección 7)

---

## 5. Decisiones abiertas

| # | Pregunta | Recomendación |
|---|---|---|
| D1 | El documento escribe con **usted** («Responda», «Su solicitud»); el bot y la regla del módulo usan **tú** | Seguir con tú, salvo que SSUSA lo pida expresamente |
| D2 | **Familia** de unidades: la hoja no la tiene y `tipo` es texto libre | SSUSA agrega la columna `familia`. Deducirla de la primera palabra del tipo es frágil |
| D3 | Hora pedida libre: hoy se aparta directo (obs. SSUSA 5); el cambio 2 pide mostrarla como A junto a 2 más y esperar | Cambiar la regla de la obs. 5, como pide el documento |
| D4 | Operador en la hoja de unidades o en una de tractos (`jalado_por`) | Leer de la unidad y, si está vacío, del tracto: sirve para los dos casos |

---

## 6. Lo que se configura sin desarrollo

- Agregar `operador_nombre`, `operador_telefono` (y `familia`, si se decide D2) a la hoja y sincronizar la fuente.
- En el Entrenamiento, en [REGLAS]: `- El contacto del operador se comparte solo cuando el servicio está confirmado.`
- Revisar que `@confirmar_servicio` no lleve `requiere=pago` si SSUSA no confirma con pago (en el ejemplo aparece «esperando pago»).
- Quitar `placas` de la directiva `{{hoja_buscar:}}` de la ruta (de todos modos F3 las oculta).

---

## 7. Pruebas

En WhatsApp y en Telegram, en un **celular real**. Probar en el inbox 493, **nunca en el 4**.

- [ ] Un servicio con horario libre: hasta 3 opciones alineadas; «adelante» aparta la A.
- [ ] Ejemplo real: «Adelante con el horario» aparta 12:00–13:00 TP-46 → estado Apartado.
- [ ] Dos servicios: «sí» aparta la A de ambos; «el 2 a las 16» aparta solo esa.
- [ ] Respuesta ambigua: «más tarde» → una pregunta con opciones cerradas, sin repetir la propuesta.
- [ ] Rechazo: «ninguna» → pide otra fecha u hora.
- [ ] Tipo inexistente (rabón): no ofrece cama baja; ofrece asesor.
- [ ] Sin horario ese día: «No hay horario el <día>; lo más cercano es…».
- [ ] Confirmación: aparece el operador; en la propuesta y en el apartado, no.
- [ ] Operador vacío en la hoja: sale «en cuanto quede asignado».
- [ ] Celular angosto: ningún renglón de la tabla se corta.
- [ ] Sin placas ni serie en ningún mensaje.
- [ ] Telegram: la tabla sale monoespaciada.

**Antes de tocar el flujo:** hay 7 pruebas de `spec/jobs/contact_tracking_response_analyzer_job_spec.rb`
(calendario y citas) que ya fallaban. OJO: RSpec corre contra `chatwoot_dev` y ya borró conversaciones
reales. Revisarlas leyendo el código o con una base de pruebas aparte.

---

## 8. Registro de fases

_(se llena al cerrar cada fase: qué se hizo, cómo funciona, pruebas y cómo pedírselo al Asistente)_
