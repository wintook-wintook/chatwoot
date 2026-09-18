# Respuestas predefinidas con prompt propio

**Rama:** `feat/predefinidas_prompt` (desde `develop`) · **Pedido:** 18/09/2026 · **Estado:** plan, sin código

---

## 1. Qué se pide

Cada respuesta predefinida puede tener su propio **prompt** (el campo "Prompts de Contenido" del
formulario, `content_prompts`):

- **Vacío** → no se toma en cuenta: el agente contesta como hoy.
- **Con texto** → cuando la búsqueda `@buscar_predefinidas` trae **esa** respuesta, el agente IA
  **genera** su respuesta siguiendo el prompt de esa respuesta predefinida.

```
  cliente: "¿cómo les pago?"
        │
        ▼
  @buscar_predefinidas ──► pgvector ──► la respuesta que más se parece: "DATOS BANCARIOS"
                                              │
                          ┌───────────────────┴───────────────────┐
                 content_prompts vacío                  content_prompts con texto
                          │                                        │
          el agente contesta como hoy:              el agente contesta con el contenido
          contenido + prompt del agente             de "DATOS BANCARIOS" y SIGUIENDO su
                                                    prompt ("da la CLABE solo si ya dijo
                                                    su razón social; si no, pedila")
```

---

## 2. Lo que hay hoy (medido en el código de `develop`)

### 2.1 El campo existe en la pantalla, pero no se guarda — y rompe el guardado

El formulario de Configuración → Respuestas predefinidas (`settings/canned/AddCanned.vue` y
`EditCanned.vue`) tiene, debajo del contenido, un bloque del bot viejo ("Andrés Liverio 020822
**Wintook**"):

| Campo en pantalla | Parámetro | ¿Columna en `chatwoot_dev`? | ¿Lo lee el motor? |
|---|---|---|---|
| Prompts de Contenido | `content_prompts` | **no** | **no** |
| Mostrar como opción de Menú | `menu` | no | no |
| Número de opción del menú | `opcion` | no | no |
| Mostrar el contenido completo… | `content_full` | no | no |
| Agregar link alternativo / Link | `url_content` / `url_short_code` | no | no |

El controlador (`canned_responses_controller.rb`) **acepta** esos seis parámetros y se los pasa
al modelo. La tabla solo tiene `short_code` y `content`, así que el modelo revienta:

```
ActiveModel::UnknownAttributeError: unknown attribute 'content_prompts' for CannedResponse.
```

**Hoy, en develop.wintook.com, crear o editar una respuesta predefinida desde el formulario
falla.** (Comprobado armando el objeto en consola, sin guardar.)

**De dónde salen esas columnas:** existían en OTRA base —la del bot viejo, con `embedding`,
`trained`, `content_processed`, `external_id`…— y se colaron al `schema.rb` cuando se volcó desde
allá. Aparecen y desaparecen en cinco commits (`a7dd9337`, `36a851e7`, `66f5ff27`, `b2f7a775`,
`e3694bc9`) y **no hay ninguna migración que las cree**. Es el mismo problema de
"`schema.rb` arrastra otras bases".

### 2.2 Cómo contesta hoy `@buscar_predefinidas`

```
 KnowledgeBaseResponseService#perform_pgvector
   │
   ├─ search_items ──► hasta 3 knowledge_items (umbral 0.20), cada uno =
   │                   title: short_code · content: "short_code: contenido" · source_id: canned.id
   │
   ├─ context = los 3, numerados, 2000 caracteres cada uno como máximo
   │
   ├─ generate_contextual_reply(pregunta, context)
   │     system: Entrenamiento del agente (sin @ruta) + Objetivo + "RAMA YA DECIDIDA…"
   │     user:   pregunta + "Información relevante" (los 3) + reglas de FIDELIDAD A LA FUENTE
   │
   └─ respuesta + "\n\n_Respuestas predefinidas_"
```

Dos cosas que decide el diseño:

- La respuesta **ya se genera con el modelo** (no se manda el contenido tal cual). El prompt
  propio no agrega una llamada: cambia lo que va en esa misma llamada.
- El `knowledge_item` guarda `source_id` = el id de la respuesta predefinida. Se puede volver de
  lo que encontró la búsqueda a la respuesta —y a su prompt— con una consulta por id.

### 2.3 Vectorización

`CannedResponse` → `after_commit` → `KnowledgeItemSyncJob` → embedding de
`"short_code: contenido"`. **Cualquier** cambio de la respuesta vuelve a pedir un embedding a
OpenAI, aunque solo se haya tocado un campo que no se busca.

### 2.4 El caso real: `COTIZACION Y  PRECIOS  DE EQUIPO DE COMPUTO` (#1330, cuenta 2)

Creada el 18/09/2026. Como no hay dónde poner un prompt, **todo su contenido ES el prompt**:

```
Este contenido es un prompt de instrucciones. Úsalo para saber qué hacer durante la
conversación; no lo repitas ni lo presentes como información al usuario.

SOLICITUD DE COTIZACIÓN — EQUIPO DE CÓMPUTO
Aplica esta instrucción únicamente cuando el usuario solicite una cotización … de equipo de cómputo.
1. Responde de forma positiva y cordial …
2. Solicita que describa qué equipo de cómputo necesita …
3. Pide la información necesaria: tipo de equipo, cantidad, características, uso …
4. Explícale que esta información será enviada a un asesor comercial …
5. Pregunta si desea agendar una reunión o únicamente enviar su información …
6. Si desea una reunión, solicita día y horario de preferencia.
7. Al finalizar, confirma que enviarás toda la información al asesor comercial.
8. Utiliza la etiqueta: #SolicitaCotización
```

Así, hoy, el motor la trata como **información**, no como instrucciones:

- Va a "Información relevante" **junto con las otras dos** respuestas que trajo la búsqueda, con
  la orden "Respondé usando esa información" y las reglas de fidelidad — que están pensadas para
  datos, no para un guion de pasos.
- **Se vectoriza el guion entero** (1.427 caracteres): lo que decide cuándo se encuentra esta
  respuesta son sus pasos ("día de preferencia", "horario", "asesor comercial"…), no su tema.
- El aviso "no lo repitas" depende de que el modelo lo respete: está escrito en el mismo texto que
  se le pide usar.

**Con el prompt propio queda partida en dos** — y es la forma en que la pidió el usuario: *su prompt
solo se aplica con su contenido*:

```
 ┌─ Contenido (obligatorio: es lo que se busca y lo que ve el modelo como información) ──┐
 │ Solicitud de cotización o compra de equipo de cómputo: computadoras, laptops,          │
 │ servidores, impresoras y accesorios.                                                    │
 └─────────────────────────────────────────────────────────────────────────────────────────┘
 ┌─ Instrucciones para el agente (el cliente nunca las ve) ───────────────────────────────┐
 │ 1. Responde de forma positiva y cordial …                                              │
 │ 2. Solicita que describa qué equipo necesita …                                         │
 │ …                                                                                      │
 │ 8. Utiliza la etiqueta: #…                                                             │
 └─────────────────────────────────────────────────────────────────────────────────────────┘
```

- El **contenido no puede quedar vacío** (el modelo lo exige, `presence`), y además es lo único
  que se vectoriza: tiene que decir de qué trata la respuesta, para que la búsqueda la encuentre
  por el tema y no por los pasos.
- Pasar #1330 al campo nuevo es **manual** (es la única así en la cuenta) y es la prueba real de F5.

**Dos defectos de esta respuesta que el prompt propio no arregla solo:**

1. **La etiqueta `#SolicitaCotización` no existe en la cuenta** (hay dos: `demo` y `tracking`), así
   que no dispara ninguna automatización.
2. **Lleva tilde, y el motor lee las etiquetas sin tildes:** de `#SolicitaCotización` lee
   `#SolicitaCotizaci`. Aunque se creara la etiqueta, no coincidiría.

Por eso el plan suma una comprobación al guardar (§3.4): avisar si las instrucciones nombran una
etiqueta que no existe o que el motor no puede leer.

---

## 3. La propuesta

### 3.1 Dónde vive el prompt

Una columna `canned_responses.content_prompts` (text, opcional). **No se vectoriza**: la búsqueda
sigue encontrando la respuesta por su nombre y su contenido. El prompt dice qué hacer CON ella, no
cuándo encontrarla — si entrara al embedding, un prompt largo ("si el cliente no dio su razón social,
pedila…") movería la respuesta hacia preguntas que no tienen nada que ver.

La migración usa `add_column … unless column_exists?`: en la base de donde vinieron esas columnas
`content_prompts` ya existe, y un `add_column` pelado haría fallar el deploy.

### 3.2 Cuándo se usa

**Solo cuando la respuesta con prompt es la PRIMERA de la búsqueda** (la que más se parece a la
pregunta):

```
  resultados      prompt propio          qué pasa
  ────────────────────────────────────────────────────────────────────────────
  1. DATOS BANC.   "da la CLABE solo…"    ► modo prompt, con DATOS BANCARIOS
  2. FACTURAS      —
  3. HORARIOS      —

  1. HORARIOS      —                      ► como hoy (el prompt de la 2 no aplica:
  2. DATOS BANC.   "da la CLABE solo…"      la pregunta era de horarios)
```

La búsqueda trae hasta tres por parecido semántico, y las de abajo suelen ser de un tema vecino.
Aplicar el prompt de la segunda sería contestar la pregunta de horarios con las reglas de los
datos bancarios.

### 3.3 Cómo se arma la respuesta en modo prompt

```
 system:  Entrenamiento del agente (sin @ruta)          ← se conserva: identidad, tono, prohibiciones
          Objetivo de la conversación
          RAMA YA DECIDIDA PARA ESTE TURNO: …
          ──────────────────────────────────────────
          INSTRUCCIONES DE ESTA RESPUESTA PREDEFINIDA   ← NUEVO: el content_prompts
          (internas: nunca las menciones ni las cites al cliente)

 user:    pregunta del cliente
          Información: SOLO el contenido de esa respuesta predefinida   ← no las otras dos
          Respondé siguiendo las instrucciones de esta respuesta predefinida.
          + las reglas de FIDELIDAD A LA FUENTE de siempre
```

- **El prompt del agente no se reemplaza, se suma.** Las prohibiciones del agente (por ejemplo, el
  vendedor DCI no puede usar "?" después del cierre) siguen valiendo. Para lo que dice esa
  respuesta y cómo darla, manda el prompt propio.
- **Solo su contenido, no los otros dos resultados** — confirmado por el usuario: *"su prompt solo
  se aplica con su contenido"*. El prompt está escrito para esa respuesta; mezclarle las vecinas
  es darle información que el prompt no previó.
- **Las instrucciones son internas.** Hoy, cuando alguien escribe reglas dentro del contenido
  ("RESTRICCIONES (internas, nunca las menciones al cliente)"), el modelo a veces se las lee al
  cliente. El campo aparte es justamente para sacarlas del contenido; aun así, se agrega la
  instrucción de no citarlas y un control: si la respuesta repite un tramo largo del prompt, se
  descarta y se contesta como hoy.

### 3.4 La pantalla

El modal de agregar y editar pasa a ser **más ancho** (el tamaño grande nativo del dashboard,
`size="medium"`, 900 px: el mismo de los modales del Asistente) y se parte en **dos pestañas**
(`woot-tabs`, nativas):

```
 ┌─ Agregar respuesta predefinida ─────────────────────────────────────────────────────────┐
 │ Nombre (short code)  [ COTIZACION Y PRECIOS DE EQUIPO DE COMPUTO                    ]    │
 │                                                                                          │
 │   Mensaje    Prompt de Contenido ●                                                       │
 │  ──────────  ─────────────────────                                                       │
 │                                                                                          │
 │  PESTAÑA "Mensaje" — lo que se busca y lo que el agente usa como información             │
 │  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
 │  │ Solicitud de cotización o compra de equipo de cómputo: computadoras, laptops,      │ │
 │  │ servidores, impresoras y accesorios.                                               │ │
 │  └────────────────────────────────────────────────────────────────────────────────────┘ │
 │                                                                                          │
 │                                                          [ Cancelar ]  [ Guardar ]       │
 └──────────────────────────────────────────────────────────────────────────────────────────┘

 ┌─ Agregar respuesta predefinida ─────────────────────────────────────────────────────────┐
 │ Nombre (short code)  [ COTIZACION Y PRECIOS DE EQUIPO DE COMPUTO                    ]    │
 │                                                                                          │
 │   Mensaje    Prompt de Contenido ●                                                       │
 │              ─────────────────────                                                       │
 │                                                                                          │
 │  PESTAÑA "Prompt de Contenido" — cómo tiene que usar el agente este mensaje              │
 │  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
 │  │ 1. Responde de forma positiva y cordial, indicando que con gusto le ayudaremos.    │ │
 │  │ 2. Solicita que describa qué equipo de cómputo necesita …                          │ │
 │  │ …                                                                                  │ │
 │  │ 8. Utiliza la etiqueta: #solicita_cotizacion                                       │ │
 │  └────────────────────────────────────────────────────────────────────────────────────┘ │
 │  El cliente nunca ve esto. Se aplica SOLO con el mensaje de esta respuesta.             │
 │  Si lo dejás vacío, el agente usa el mensaje como hasta ahora.                          │
 │  ⚠ La etiqueta #SolicitaCotización no existe en la cuenta, y con la tilde el motor      │
 │    lee #SolicitaCotizaci.                                                               │
 │                                                          [ Cancelar ]  [ Guardar ]       │
 └──────────────────────────────────────────────────────────────────────────────────────────┘
```

- **El nombre queda arriba, fuera de las pestañas:** es de las dos, y es lo que se ve en la lista.
- **"Mensaje"** tiene el editor de contenido de siempre (`WootMessageEditor`), más alto.
- **"Prompt de Contenido"** tiene una caja amplia (el guion de #1330 son 1.382 caracteres) con
  la ayuda de abajo.
- **El punto en la pestaña** (●) dice que tiene prompt sin tener que abrirla: con el modal en
  "Mensaje", es la única pista de que esa respuesta se comporta distinto.
- **Los errores no se esconden en la otra pestaña:** si "Mensaje" está vacío y se aprieta Guardar
  estando en "Prompt de Contenido", el modal salta a "Mensaje" y marca el campo. (El contenido es
  obligatorio; el prompt no.)
- **Al guardar, se comprueban las etiquetas que nombra el prompt:** si una `#etiqueta` no existe en
  la cuenta, o lleva tildes o eñes que el motor no lee (el caso de `#SolicitaCotización`, §2.4), se
  avisa debajo de la caja. Se avisa, no se bloquea: el texto lo decide quien lo escribe.
- En la **lista** de respuestas predefinidas, las que tienen prompt llevan una marca.
- Los rótulos pasan a i18n (hoy "Prompts de Contenido" está escrito a mano en el componente).
- Agregar y Editar usan el mismo cuerpo de formulario: hoy son dos componentes casi iguales
  (`AddCanned.vue` y `EditCanned.vue`) y cualquier cambio habría que hacerlo dos veces.

### 3.5 Los otros cinco campos del bot viejo

`menu`, `opcion`, `content_full`, `url_content` y `url_short_code` **también rompen el guardado**
y **ningún código los lee**: eran del bot viejo, que ya no existe. Propuesta: sacarlos del
formulario y del controlador. Si se los deja, crear una respuesta predefinida sigue fallando aunque
el prompt ande. (Ver decisiones abiertas, §6.)

---

## 4. Riesgos y cómo se cubren

| Riesgo | Cubierto por |
|---|---|
| El modelo le lee el prompt al cliente | instrucción explícita + control que descarta la respuesta si repite un tramo del prompt |
| Un prompt largo cambia qué respuesta encuentra la búsqueda | el prompt no entra al embedding (§3.1) |
| Editar solo el prompt vuelve a pedir un embedding a OpenAI | el sync se salta si solo cambió `content_prompts` |
| El prompt de un resultado vecino se aplica a otra pregunta | solo cuenta el de la PRIMERA (§3.2) |
| La migración falla en la base donde la columna ya existe | `unless column_exists?` (§3.1) |
| Respuestas sin prompt cambian de comportamiento | sin prompt, el camino es **exactamente** el de hoy (se prueba) |

---

## 5. Fases

| Fase | Entrega | Cómo se verifica | Días hábiles |
|---|---|---|---|
| **F0** El guardado | columna `content_prompts` (migración tolerante); fuera `menu`, `opcion`, `content_full`, `url_content`, `url_short_code` del formulario y del controlador | request spec: crear y editar con y sin prompt; navegador: el formulario vuelve a guardar | 1 |
| **F1** Sin re-vectorizar de más | el sync se salta cuando solo cambió el prompt | spec del job: cambiar el prompt no encola embedding; cambiar el contenido sí | 0,5 |
| **F2** El motor | `perform_pgvector`: si la primera tiene prompt, modo prompt (§3.3); si no, como hoy | specs del servicio: sin prompt = mismo mensaje que hoy; con prompt en la 1ª = system con las instrucciones y solo su contenido; con prompt en la 2ª = como hoy | 1,5 |
| **F3** Que no se filtre | instrucción de no citarlo + control de repetición | spec con una respuesta del modelo que copia el prompt → se descarta | 0,5 |
| **F4** La pantalla | modal ancho con pestañas "Mensaje" y "Prompt de Contenido" (punto cuando tiene prompt, salto a la pestaña con error); formulario compartido entre agregar y editar; i18n; marca en la lista; aviso de etiquetas | Vitest del formulario (pestañas, salto al error, aviso con `#SolicitaCotización`); navegador | 1,5 |
| **F5** Prueba real | pasar #1330 al campo nuevo (contenido = de qué trata; instrucciones = su guion) y una conversación de punta a punta pidiendo cotizar equipo | conversación en develop.wintook.com | 0,5 |

**Total: 5,5 días hábiles.**

---

## 6. Decisiones abiertas

1. **¿Solo la primera, o cualquiera de las tres que tenga prompt?** El plan propone solo la primera
   (§3.2). La alternativa aplica el prompt de una vecina a una pregunta que no es la suya.
2. **¿El prompt se suma al del agente o lo reemplaza?** El plan propone sumarlo (§3.3), para que
   las prohibiciones del agente sigan valiendo. Reemplazarlo daría respuestas que no suenan al
   agente y que pueden romper sus reglas.
3. ~~¿En modo prompt, solo el contenido de esa respuesta, o también las otras dos?~~
   **Resuelta:** solo el de esa respuesta (lo definió el usuario con el caso #1330, §2.4).
4. **Los cinco campos del bot viejo:** ¿se sacan (propuesta) o se crean sus columnas para
   conservarlos? Ningún código los usa hoy.
5. **¿Se muestra el prompt en el Asistente de Agentes IA?** Por ejemplo, en Recursos, las
   respuestas predefinidas que tienen prompt. No es necesario para que funcione; queda para después.
