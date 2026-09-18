# Respuestas predefinidas con prompt propio

**Rama:** `feat/predefinidas_prompt` (desde `develop`) · **Pedido:** 18/09/2026 · **Estado:** F0, F1, F4 y el guardado de F6 hechos; F2, F3, F5, el resto de F6 ("tal cual" y link en el modal nuevo) y F7–F8 pendientes

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

### 2.5 Lo que hay en una base tipo producción (`chatwoot_staging_v2`, solo lectura)

| En `canned_responses` | Respuestas |
|---|---|
| total | **1.870** |
| con `content_prompts` | **1.047**, en **95 cuentas** (largo mediana 321, máximo 2.741; última edición 09/07/2026) |
| `content_full` (tal cual) | 563 |
| con link (`url_content`) | 697 |
| en el menú (`menu`) | 309 |

**⚠ Los `content_prompts` que ya existen significan OTRA cosa.** Una muestra al azar:

```
  "¿Qué indicación visual confirma que la a…" → Esta es la respuesta que darás si alguien te pregunta
                                                ¿Qué indicación visual confirma que la actualización se…
  "Modificar escalas en diagrama de Gantt"     → Esta será tu respuesta cuando alguien te pregunte
                                                ¿Cómo modificar escalas de Diagrama de Gantt? o escriba las…
```

Los escribió el bot viejo para **encontrar** la respuesta (esa tabla tiene además `embedding`,
`trained` y `content_processed`): dicen **cuándo** darla. El prompt de este plan dice **cómo** darla
(el guion de #1330). Mismo campo, dos significados.

Consecuencia: si F2 sale tal cual está en §3, en una base como esa **1.047 respuestas de 95 cuentas
cambian de comportamiento de un día para otro**, con instrucciones que nadie escribió para eso. La
frase vieja es mayormente inofensiva ("esta es la respuesta que darás si…"), pero no es lo que se
probó ni lo que se quiso. Ver la decisión 7 (§6).

### 2.6 Quién usa esos campos en staging.wintook.com (medido, solo lectura)

`staging.wintook.com` → nginx → puerto 3020 → `/home/chatwoot_staging/chatwoot` (rama `staging`,
`2188003d`) → base **`chatwoot_staging_v2`** (la de §2.5).

```
                ┌────────────────── chatwoot_staging_v2 ──────────────────┐
                │ public.canned_responses                                  │
                │   short_code · content · content_prompts · content_full │
                │   url_content · url_short_code · menu · opcion          │
                │   trained · embedding · content_processed …             │
                │ esquemas del bot: wintook · openai (embedding, resources)│
                │                   chatzeus                               │
                └─────────▲──────────────────────────────────▲─────────────┘
                          │ GUARDA (el controlador            │ LEE y ENTRENA
                          │ acepta los campos)                │ (fuera de Chatwoot)
                ┌─────────┴─────────┐              ┌──────────┴────────────────┐
                │ Chatwoot staging  │              │ servicios Wintook externos│
                │ (su backend Ruby  │              │ bot.wintook.com     → 404 │
                │ NO lee ninguno)   │              │ openai.wintook.com  → 403 │
                └───────────────────┘              │ api.wintook.com     → 403 │
                                                   └───────────────────────────┘
```

- **El backend de Chatwoot de staging no lee esos campos en ninguna parte:** solo el controlador los
  guarda. Quien los usa está **fuera de Chatwoot**: los servicios Wintook (la pantalla "Entrenamiento
  ChatGPT" de staging habla con `openai.wintook.com`; la base tiene su esquema `openai` con
  `embedding` y `resources`).
- **Esos servicios responden** (404/403 en la raíz: están en pie, no caídos). No se los consultó más
  allá de eso.
- **La llamada `setCannedReponse` tampoco funciona en staging:** `URL_WEBHOOK` no está definida ahí
  tampoco (solo `WINTOOK_BOT`, `WINTOOK_API` y `WINTOOK_OPENAI`). Borrarla no cambia nada.

**⚠ Lo que implica: el mismo campo lo van a leer DOS motores.** Si el motor de Chatwoot empieza a
usar `content_prompts` como instrucciones (F2) y alguien escribe ahí un guion como el de #1330, los
servicios Wintook **también** lo van a leer —y lo usan para otra cosa: entrenar y encontrar la
respuesta (§2.5)—. Ver decisión 8 (§6).

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

### 3.5 Los cinco campos del bot viejo, nativos en Chatwoot

**Decidido el 18/09/2026:** se traen a Chatwoot. Hoy quedaron escondidos detrás de la bandera
`SHOW_LEGACY_FIELDS` (F0 ya hecha): no se muestran ni se mandan, para que el guardado no falle.

#### Qué hacía el bot con ellos

Editar una respuesta llamaba a `URL_WEBHOOK/api/setCannedReponse` con esos cinco campos, y
`getCannedReponse` los leía de vuelta. **Esa API no hacía nada más que guardar**: el
comportamiento vivía en el bot.

**Corrección (18/09/2026, medido):** no los guardaba en una base aparte. En `chatwoot_staging_v2`
—una copia de una base tipo producción que está en este mismo servidor, con los esquemas del bot
(`wintook`, `openai`, `chatzeus`) junto al `public` de Chatwoot— las columnas están **en la propia
tabla `canned_responses` de Chatwoot**, con datos (ver §2.5). Es de ahí de donde se colaron al
`schema.rb`. Donde esas columnas existen, la API de Chatwoot ya las guardaba (el controlador las
aceptaba); el único lugar donde reventaba era `chatwoot_dev`, que no las tiene.

Y en esta instalación **nunca funcionó**:

```
 Editar  ──► process.env.URL_WEBHOOK  ──► no está definida en ninguna parte (webpack, .env)
              └─► POST https://develop.wintook.com/undefined/api/setCannedReponse  → 404
 Agregar ──► tenía la función hacia WINTOOK_BOT (https://bot.wintook.com), pero no la llamaba
 bot.wintook.com hoy ──► 404 · su código no está en este servidor
```

En `chatwoot_dev` esos campos no se guardaban en ningún lado y **arrancan vacíos**. En una base como
`chatwoot_staging_v2` **no hay nada que migrar**: los datos ya están en la tabla de Chatwoot, y la
migración tolerante no toca una columna que ya existe.

#### Qué se trae y qué no

| Campo(s) | En el bot | En Chatwoot | Esta rama |
|---|---|---|---|
| `content_full` | mostrar el contenido completo en el resultado de la búsqueda | **enviar el mensaje tal cual**, sin que el modelo lo redacte | **sí** |
| `url_content` + `url_short_code` | agregar un link de dirección web alternativa | el link al final de la respuesta | **sí** |
| `menu` + `opcion` | mostrar la respuesta como opción numerada del menú del bot | — | **no**: es otro proyecto (depende del "Menú del sistema", cuya configuración también le habla al bot viejo) |

`menu` y `opcion` se guardan igual (la columna no cuesta nada y así no se pierden si alguien los
carga), pero siguen escondidos en el formulario hasta que exista el menú.

**Guardarlos no necesita ninguna API:** es una migración tolerante, igual a la de `content_prompts`
(`unless column_exists?`, porque en la base del bot ya existen), y apagar la bandera. El controlador
ya acepta solo las columnas que la tabla tiene (F0), así que los toma solo. Antecedente: los
sinónimos ya se pasaron del bot viejo a Rails nativo (`6e3a1d98`).

La llamada a `setCannedReponse` se **borra** en esta fase: su único trabajo era guardar en la base
del bot, y ahora se guarda en la de Chatwoot.

#### Los tres modos de responder con una respuesta predefinida

Con `content_full`, una respuesta predefinida puede contestar de tres maneras. Son excluyentes, y el
formulario lo deja claro:

```
  la búsqueda trae esta respuesta primera
          │
          ├── "Enviar tal cual" marcado ─────► se manda el MENSAJE exacto, sin pasar por el modelo
          │                                   (+ el link, si tiene)
          │
          ├── tiene Prompt de Contenido ─────► el modelo redacta con el mensaje y SU prompt (§3.3)
          │                                   (+ el link, si tiene)
          │
          └── ninguna de las dos ────────────► como hoy: el modelo redacta con las 3 que trajo
                                              (+ el link, si tiene)
```

- **"Tal cual" y el prompt no conviven:** un mensaje que se manda exacto no se puede redactar
  siguiendo instrucciones. Si se marca "Enviar tal cual", la pestaña del prompt se apaga y lo dice.
- **Las variables se resuelven solas:** un `{{contact.name}}` en el mensaje lo reemplaza Chatwoot
  al crear el mensaje saliente (`Liquidable#process_liquid_in_content`, `before_create`), el mismo
  procesador que usa cualquier respuesta enviada. Verificado en el código; hoy ninguna de las 4
  respuestas de la cuenta usa variables.
- **"Tal cual" es la opción segura** para textos que no se pueden alterar: datos bancarios, una
  CLABE, una política con redacción legal. Hoy el modelo los reescribe siempre.
- **El link** va al final, en su renglón, antes de la etiqueta de la fuente (`_Respuestas
  predefinidas_`). Se valida que sea una URL al guardar.

#### Dónde van en el modal

En la pestaña **"Mensaje"**, debajo del editor, porque dicen qué se hace con el mensaje:

```
 │  Mensaje    Prompt de Contenido                                                  │
 │  [ editor del mensaje …                                                       ]  │
 │                                                                                  │
 │  ☐ Enviar tal cual (sin que el agente lo redacte)                               │
 │  ☐ Agregar un link al final   [ https://kontrolya.com/precios/              ]   │
```

---

---

### 3.6 La casilla "El mensaje es el prompt" (`content_is_prompt`)

Pedido del usuario (18/09/2026): una casilla aparte de `content_prompts` que marca que el
**mensaje mismo** de la respuesta es el prompt, es decir, instrucciones para el agente IA y no
información para el cliente.

```
┌─ Editar respuesta predefinida ───────────────────────────────┐
│ Nombre  [ COTIZACION EQUIPO                              ]   │
│ ┌ Mensaje ┐ Prompt de Contenido ●                            │
│ │ …                                                          │
│ ├──────────────────────────────────────────────────────────  │
│ │ [x] El mensaje es el prompt                                │
│ │     (instrucciones para el agente, no para el cliente)     │
│ │ [ ] Mostrar como opción de Menú.  … (campos del bot viejo)  │
└──────────────────────────────────────────────────────────────┘
```

- Columna `content_is_prompt` boolean, default `false`, not null. No existe en
  `chatwoot_staging_v2`: es nueva, y todas las respuestas que ya existen quedan apagadas.
- La guarda la API de Chatwoot como los demás campos; en la lista sale la marca "Mensaje = prompt".
- **Hecho:** guardado, modal y marca en la lista. **Falta:** que el motor la use (va con F2); hay que
  definir cómo se combina con `content_prompts` cuando la respuesta tiene las dos cosas.

### 3.7 La regla del motor (decidida por el usuario, 18/09/2026) — IMPLEMENTADA

Sobre la **primera** respuesta predefinida que encuentra `@buscar_predefinidas`:

```
                     ┌─────────────────────────────┐
                     │ respuesta encontrada (1ª)   │
                     └──────────────┬──────────────┘
                  ¿content_is_prompt = true?
                   ┌────────── sí ──┴── no ──────────┐
                   ▼                                 ▼
   ┌───────────────────────────────┐   ¿content_prompts con texto?
   │ A · el mensaje ES el prompt   │     ┌──── sí ───┴─── no ────┐
   │ content_prompts se ignora     │     ▼                       ▼
   └───────────────────────────────┘  ┌────────────────────┐  ┌──────────────┐
                                      │ B · mensaje = info │  │ C · como     │
                                      │ content_prompts =  │  │ siempre      │
                                      │ cómo responder     │  └──────────────┘
                                      └────────────────────┘
```

- A y B usan **solo** esa respuesta (no las otras dos). Si la que tiene prompt sale 2ª o 3ª: C.
- Las instrucciones se **suman** a las del agente: su prompt sigue en el system, con el objetivo y la
  regla de la rama al final. Van en el mensaje del turno, marcadas como internas.
- **Que no se filtre:** se le pide no citarlas, y si la respuesta copia 8 palabras seguidas de ellas
  (sin contar lo que va entre comillas, que es texto para decir) se descarta, no se guarda en el
  historial y se responde como siempre (C).
- Los 1.047 prompts viejos de staging entran en B en cuanto esto llegue allá (aceptado por el usuario).
- Código: `KnowledgeBase::CannedPrompt` + `KnowledgeBaseResponseService#canned_prompt_reply`.
  No cubre `KnowledgeBase::DirectiveRunner` (API externa `/knowledge_base/directive`) ni la prueba en
  seco del Asistente, que no redacta.

### 3.8 Guion en curso (opción B, elegida por el usuario 18/09/2026) — IMPLEMENTADO

Un prompt suele ser un guion de varios mensajes, pero la búsqueda es por mensaje: "5 laptops i7" o
"el martes a las 10" ya no traen la respuesta del guion en primer lugar. Cuando una respuesta con
prompt se usa, la conversación la recuerda (`additional_attributes.kb_canned_prompt`) y la sigue
aplicando:

```
"quiero cotizar laptops"  → #1330 sale 1ª → aplica guion → 📌 en curso: #1330 (1)
"5 laptops i7, oficina"   → sale otra     → 📌 sigue #1330 (2) + lo encontrado, por si acaso
"el martes a las 10"      → no sale nada  → 📌 sigue #1330 (3)
respuesta con #solicita_cotizacion        → 🏁 se suelta
```

Se suelta con lo primero que pase: la respuesta trae una etiqueta **que el guion nombra**; la
búsqueda trae primera **otra** respuesta con prompt (se cambia a esa); el clasificador cambia de
**ruta**; **8 mensajes** o **24 h** sin usarse; la respuesta se borró o dejó de tener prompt.

A mitad del guion el modelo recibe "GUION EN CURSO: continúa desde donde quedó, no repitas pasos ni
pidas datos ya dados", las instrucciones, y lo que encontró la búsqueda en ese mensaje (para
contestar una pregunta suelta y retomar). Una respuesta descartada por filtración no hace avanzar el
guion. La agenda (`@agendar_calendar`) y `@crear_ticket` corren antes que la búsqueda en el job, así
que pueden tomar un mensaje en medio del guion sin romperlo.

**Qué pide esto del contenido:** que el guion termine con una etiqueta escrita en él (la de cierre),
y que su condición de uso no impida seguirlo en los mensajes siguientes.

## 4. Riesgos y cómo se cubren

| Riesgo | Cubierto por |
|---|---|
| El modelo le lee el prompt al cliente | instrucción explícita + control que descarta la respuesta si repite un tramo del prompt |
| Un prompt largo cambia qué respuesta encuentra la búsqueda | el prompt no entra al embedding (§3.1) |
| Editar solo el prompt vuelve a pedir un embedding a OpenAI | el sync se salta si solo cambió `content_prompts` |
| El prompt de un resultado vecino se aplica a otra pregunta | solo cuenta el de la PRIMERA (§3.2) |
| La migración falla en la base donde la columna ya existe | `unless column_exists?` (§3.1) |
| Respuestas sin prompt cambian de comportamiento | sin prompt, el camino es **exactamente** el de hoy (se prueba) |
| "Tal cual" manda un mensaje con variables sin reemplazar | lo resuelve el mismo `Liquidable` de todo mensaje saliente (se prueba con `{{contact.name}}`) |
| Se marca "tal cual" y además hay prompt | son excluyentes en el formulario; en el motor, "tal cual" gana y se registra en el log |
| Las columnas viejas ya existen en la base tipo producción | migración tolerante, como la de `content_prompts`: no las toca y los datos quedan |
| 1.047 prompts del bot viejo, con otro significado, entran de golpe al modo prompt | decisión 7: activación explícita por respuesta |

---

## 5. Fases

| Fase | Entrega | Cómo se verifica | Días hábiles |
|---|---|---|---|
| **F0** ✅ El guardado | columna `content_prompts` (migración tolerante); el controlador acepta solo columnas reales; los campos viejos detrás de `SHOW_LEGACY_FIELDS` | request spec: crear y editar con y sin prompt, y con los campos viejos sin reventar | 1 |
| **F1** ✅ Sin re-vectorizar de más | el sync se salta cuando solo cambió el prompt | spec del job: cambiar el prompt no encola embedding; cambiar el contenido sí | 0,5 |
| **F2** ✅ El motor | `perform_pgvector`: si la primera tiene prompt, modo prompt (§3.3); si no, como hoy | specs del servicio: sin prompt = mismo mensaje que hoy; con prompt en la 1ª = system con las instrucciones y solo su contenido; con prompt en la 2ª = como hoy | 1,5 |
| **F3** ✅ Que no se filtre | instrucción de no citarlo + control de repetición | spec con una respuesta del modelo que copia el prompt → se descarta | 0,5 |
| **F4** ✅ La pantalla | modal ancho con pestañas "Mensaje" y "Prompt de Contenido" (punto cuando tiene prompt, salto a la pestaña con error); formulario compartido entre agregar y editar; i18n; marca en la lista; aviso de etiquetas | Vitest del formulario (pestañas, salto al error, aviso con `#SolicitaCotización`); navegador | 1,5 |
| **F5** Prueba real | pasar #1330 al campo nuevo (contenido = de qué trata; instrucciones = su guion) y una conversación de punta a punta pidiendo cotizar equipo | conversación en develop.wintook.com | 0,5 |

| **F6** (guardado ✅) Los campos viejos, nativos | migración tolerante de `menu`, `opcion`, `content_full`, `url_content`, `url_short_code`; se borra la llamada a `setCannedReponse`; en el modal, "Enviar tal cual" y "Agregar un link" en "Mensaje" (`menu`/`opcion` siguen escondidos) | request spec: se guardan y se leen; Vitest: "tal cual" apaga la pestaña del prompt | 1 |
| **F7** "Tal cual" en el motor | la primera con `content_full` se manda exacta, sin modelo; las variables las resuelve `Liquidable` | spec del servicio: no llama a OpenAI y el mensaje sale igual; `{{contact.name}}` reemplazado | 0,5 |
| **F8** El link | se agrega al final en los tres modos, antes de la etiqueta de la fuente | spec del servicio en los tres modos; validación de URL | 0,5 |

**Total: 7,5 días hábiles** (3 ya hechos: F0, F1 y F4).

---

## 6. Decisiones abiertas

1. **¿Solo la primera, o cualquiera de las tres que tenga prompt?** El plan propone solo la primera
   (§3.2). La alternativa aplica el prompt de una vecina a una pregunta que no es la suya.
2. **¿El prompt se suma al del agente o lo reemplaza?** El plan propone sumarlo (§3.3), para que
   las prohibiciones del agente sigan valiendo. Reemplazarlo daría respuestas que no suenan al
   agente y que pueden romper sus reglas.
3. ~~¿En modo prompt, solo el contenido de esa respuesta, o también las otras dos?~~
   **Resuelta:** solo el de esa respuesta (lo definió el usuario con el caso #1330, §2.4).
4. ~~Los cinco campos del bot viejo: ¿se sacan o se crean sus columnas?~~
   **Resuelta (18/09/2026):** los seis campos (`content_prompts` y los cinco del bot viejo) los guarda
   la API de Chatwoot, en su tabla; se ven y se editan en el modal con sus rótulos de siempre. Sin
   llamadas al bot: se borraron `setCannedReponse` y `getCannedReponse`. La migración usa los mismos
   tipos que en `chatwoot_staging_v2`, así que allá no hace nada y los datos quedan.
6. **El menú numerado** (`menu`/`opcion` y la pestaña "Menú del sistema"): proyecto aparte. Hoy
   la configuración de esa pestaña también depende del bot viejo (`getSystemSettings` /
   `setSystemSettings` contra `bot.wintook.com`).
5. **¿Se muestra el prompt en el Asistente de Agentes IA?** Por ejemplo, en Recursos, las
   respuestas predefinidas que tienen prompt. No es necesario para que funcione; queda para después.
7. **Los 1.047 prompts que ya existen (§2.5).** Escritos por el bot viejo para *encontrar* la
   respuesta, no para *redactarla*. Opciones:
   - **(propuesta) Activación explícita:** una casilla por respuesta, "Usar el prompt como
     instrucciones". Las nuevas y las que se editen desde el modal nuevo quedan activadas; las 1.047
     viejas, apagadas hasta que alguien las revise. Nada cambia sin que nadie lo decida.
   - **Aplicarlas a todas:** su frase es mayormente inofensiva, pero se prueba antes con una muestra
     de cada cuenta. Más rápido, y con 95 cuentas de por medio.
   - **Otra columna para las instrucciones nuevas**, y `content_prompts` queda con su significado
     viejo (y podría volver a usarse para mejorar la búsqueda, que es para lo que se escribió).
     Contradice lo pedido: el campo del modal es `content_prompts`.
8. **Dos motores sobre el mismo campo (§2.6).** En staging (y, por lo visto, en producción) los
   servicios Wintook externos leen `content_prompts`, `content_full`, el link y el menú desde la
   base. Opciones:
   - **Compartirlo** (lo pedido: el campo del modal es `content_prompts`): hay que confirmar con
     quien mantiene los servicios Wintook qué hacen con ese campo y si un guion de instrucciones
     ahí les rompe algo — por ejemplo, el entrenamiento.
   - **Separarlo:** una columna nueva solo para las instrucciones del motor de Chatwoot, y
     `content_prompts` queda para los servicios Wintook. Cero interferencia entre los dos motores,
     pero es otro campo en el modal.
   Mientras los servicios Wintook sigan en pie, esta decisión va antes que la 7.
