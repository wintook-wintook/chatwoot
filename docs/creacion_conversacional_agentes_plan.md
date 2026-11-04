# Crear un Agente IA conversando — Plan v1.0

> Solo plan (03/11/2026). Nada implementado. Rama `feat/crear_agente_conversando`: sale de develop **e incluye `feat/diagrama_agente_ia`** (el diagrama y las pruebas no tienen PR propio: llegan a develop con esta rama). Parte de la especificación «Facilitar la creación de
> agentes de IA mediante una experiencia conversacional» y de lo que el Asistente de Agentes IA ya
> hace hoy. Regla del plan: **no inventar mecanismos que el motor ya tiene**; poner pantalla y
> conversación encima de ellos.

---

## 1. Lo que pide la especificación contra lo que ya existe

| # | Pide | Hoy | Falta |
|---|---|---|---|
| 1 | Crear el agente conversando | ✅ Chat «desde cero» (`DraftingChat`, gpt-5.4-mini) llena las Instrucciones iniciales y «Crear el Entrenamiento» las convierte | Que la conversación llene también **Definición, Variables y Preguntas/Constantes**, no solo el texto |
| 2 | Guiar objetivo, contexto, instrucciones | ✅ Objetivo y Contexto salen de la ficha al crear (`BriefComposer` → `proposal`) | Que se vean llenarse **durante** la conversación, no solo al final |
| 3 | Capturar las variables del motor | ⚠ El motor ya las usa (`[VARIABLES]`, guardadas por conversación, PR #69), pero **solo se escriben a mano en el texto**; el Asistente no las conoce | Formulario + comprobador |
| 4 | Constantes reutilizables (EMPRESA, Q1…) | ❌ No existen | Sección, formulario, expansión en el motor, comprobador |
| 5 | Banco de preguntas por contexto | ❌ Hoy son renglones sueltos dentro de las rutas | Las preguntas como constantes de tipo «pregunta» (§5) |
| 6 | Ver cómo se procesa una consulta | ✅ Pestaña «Pruebas y diagrama» (de feat/diagrama_agente_ia, incluida en esta rama) | **Que sea parte de la conversación**: cada ruta propuesta llega con sus pruebas y se ve iluminada (§7) |
| 7 | Exportar instrucciones para ChatGPT / Claude | ⚠ Se descargan las *Instrucciones iniciales* y existe «Copiar todo» del Entrenamiento | Un **«Exportar instrucciones»** del agente terminado, que se entienda fuera del motor |
| 8 | Instrucciones y recursos separados | ✅ «Recursos del motor» ya se descarga aparte (`recursos_motor_agentes_ia.md`) | Ponerlas juntas en un solo menú «Exportar», como dos archivos |

```
                  ┌──────────── HOY ─────────────┐   ┌──────── ESTE PLAN ────────┐
 Conversación ──► │ Instrucciones iniciales (.md)│   │ + Definición en vivo      │
                  │        │ «Crear»             │   │ + Variables (formulario)  │
                  │        ▼                     │   │ + Constantes / Preguntas  │
                  │ Entrenamiento (texto)        │   │ + Comprobador las revisa  │
                  │  Definición: Objetivo·Contex.│   │ + Exportar: 2 archivos    │
                  │  Rutas · Secciones           │   │                           │
                  │  [VARIABLES] a mano ⚠        │   │                           │
                  └──────────────────────────────┘   └───────────────────────────┘
```

---

## 2. Tres cosas que se llaman parecido y no hay que mezclar

| Nombre en pantalla (propuesta) | Qué es | Dónde vive | Cambia durante la conversación con el cliente |
|---|---|---|---|
| **Variables** | Lo que el agente va recordando del cliente: `CARRERA`, `LIGA_ENTREGADA` | Sección `[VARIABLES]` del Entrenamiento; los valores, en cada conversación (`additional_attributes`) | **Sí** |
| **Datos fijos** (las «constantes») | Valores escritos una vez y citados en varias partes: `EMPRESA`, `PRODUCTO`, `Q1` | Sección nueva `[DATOS FIJOS]` del Entrenamiento | **No** |
| Pendientes de adaptar | Los `<PENDIENTE:>` de un prompt publicado (pestaña «Configurar») | Texto del Entrenamiento hasta que se llenan | No: se reemplazan una vez y desaparecen |

> ⚠ La pestaña «Configurar» ya le dice «variables» a los `<PENDIENTE:>`. Si se dejan así, el
> cliente verá dos cosas distintas llamadas igual. Decisión **D3**.

---

## 3. Variables — formulario encima de lo que ya existe

No hay mecanismo nuevo. El formulario **lee y escribe la sección `[VARIABLES]` del texto**
(`ConversationVariables::Definition.parse`), así que lo que se escriba a mano y lo del formulario
son lo mismo.

```
 Estructura del agente                 Modal «Variables»
 ├─ Definición del agente              ┌───────────────────────────────────────────────┐
 │   ├─ Objetivo                       │ Nombre          Valores posibles      Inicia  │
 │   ├─ Contexto                       │ CARRERA         (lo que diga el cliente) vacía│
 │   └─ Variables (3)  ◄── nuevo       │ LIGA_ENTREGADA  NO | SÍ               NO      │
 ├─ Rutas                              │ INTERES         ALTO | MEDIO | BAJO   MEDIO   │
 └─ Secciones                          │ [+ Agregar variable]                          │
                                       │ ⓘ Se guardan en cada conversación; el agente  │
                                       │   las lee y las cambia solo.                  │
                                       └───────────────────────────────────────────────┘
                                                      │ escribe
                                                      ▼
                                       [VARIABLES]
                                       CARRERA = valor
                                       LIGA_ENTREGADA = NO | SÍ
                                       INTERES = ALTO | MEDIO | BAJO
                                       Inicial: LIGA_ENTREGADA=NO; INTERES=MEDIO
```

Diferencia con Objetivo y Contexto: esos dos son **columnas del agente** y no pasan por el texto.
Las Variables **sí son texto del Entrenamiento**: pasan por el comprobador, entran a las versiones
y se publican con el agente. El modal lo dice.

**Comprobador (nuevo, ámbar):**

| Clave | Qué detecta | Ejemplo |
|---|---|---|
| V1 | Se usa una variable que no está declarada | «Si BECA=SÍ…» y no hay `BECA` |
| V2 | Se declara y nadie la lee ni la cambia | `INTERES` sin uso |
| V3 | Se compara o se asigna un valor que no está en su lista | «Marca LIGA_ENTREGADA=ENVIADA» |
| V4 | El valor inicial no está en la lista | `Inicial: INTERES=NINGUNO` |

---

## 4. Datos fijos (constantes)

### 4.1 Cómo se escriben

```
[DATOS FIJOS]
EMPRESA = Kontrolya
PRODUCTO = Kontrolya Facturación
Q1 (pregunta) = ¿Qué sistemas utilizas hoy?            → guarda en SISTEMA
Q2 (pregunta) = ¿Dónde nos conociste? (Facebook, WhatsApp, recomendación…)
```

Y en cualquier parte del Entrenamiento:

```
[BIENVENIDA]
Saluda y presenta a %EMPRESA%. Pregunta %Q2%.

@DEMO
Antes de agendar la demo de %PRODUCTO%, haz %Q1%.
```

- **Tipo**: `texto` (por omisión) · `pregunta` · `liga` · `número`. El tipo sirve para el formulario,
  para el comprobador y para el diagrama; el motor los trata igual.
- **«→ guarda en VARIABLE»** (solo preguntas, opcional): une el banco de preguntas con las
  Variables. La respuesta del cliente a Q1 se guarda en `SISTEMA`. No es un mecanismo nuevo: se
  traduce a la regla que el motor ya entiende («al contestar, marca SISTEMA=…»).
- **Sintaxis `%NOMBRE%`** (decisión **D2**). Lo que ya está ocupado y por eso no sirve:

| Signo | Ya lo usa |
|---|---|
| `{{ }}` | directivas (`{{doc:}}`, `{{hoja:}}`, `{{consulta:}}`, adjuntos `{{nombre}}`) |
| `@` | rutas |
| `$` | patrones del editor del Asistente |
| `#` | etiquetas |
| `[ ]` | secciones y referencias entre secciones (`SectionRefs`) |
| `<PENDIENTE:>` | pendientes de un prompt publicado |

### 4.2 Quién los sustituye (decisión D1)

```
 Opción A — el modelo los lee                Opción B — el motor los sustituye  ★ recomendada
 ───────────────────────────────            ──────────────────────────────────────────────
 Entrenamiento con %EMPRESA% y               Entrenamiento con %EMPRESA% y [DATOS FIJOS]
 [DATOS FIJOS] ──► modelo                          │ PromptConstants.expand (un paso)
                                                   ▼
 + cero cambios en el motor                  «Saluda y presenta a Kontrolya…» ──► modelo
 + el .md exportado sirve tal cual           + el modelo nunca ve «%Q1%»: no se le escapa
 − el modelo puede escribir «Q1» al          + menos texto en cada llamada (la sección no va)
   cliente                                   + igual en seco, en vivo y en seguimientos
 − gasta la sección completa en cada         − hay que llamarlo donde se arma el prompt
   llamada
```

**Por qué B.** El texto del agente (`complementary_prompt`) se lee en unos 70 lugares, pero casi
todos solo **buscan directivas** (`@crear_ticket`, `{{nombre}}`, `sigue`); a esos los datos fijos no
les importan. El texto **llega al modelo** en dos lugares: `KnowledgeBaseResponseService` y
`ContactTrackingResponseAnalyzerJob` (los mismos donde ya entra `ConversationVariables.rule_for`).
Se sustituye ahí, en el **seco** (`DryRunService`, para que el diagrama y las pruebas vean lo
mismo) y al **exportar**.

Los seguimientos usan una **copia** del Entrenamiento ([[project_revision_conversaciones]]): como
la sección `[DATOS FIJOS]` viaja dentro del texto, la copia la trae y se sustituye igual. Cambiar
un dato fijo cuenta como un cambio del Entrenamiento: se publica y deja versión.

**Comprobador (nuevo):**

| Clave | Qué detecta | Color |
|---|---|---|
| C1 | `%ALGO%` sin declarar | rojo: el agente vería el texto tal cual |
| C2 | Dato fijo declarado y nunca usado | ámbar |
| C3 | Pregunta con «→ guarda en X» y X no es Variable | ámbar |
| C4 | Nombre repetido o con espacios | rojo |

### 4.3 El formulario

```
 Datos fijos                                                    [+ Agregar]
 ┌──────────┬───────────┬──────────────────────────────────┬────────────┬─────────┐
 │ Nombre   │ Tipo      │ Contenido                        │ Guarda en  │ Se usa  │
 ├──────────┼───────────┼──────────────────────────────────┼────────────┼─────────┤
 │ EMPRESA  │ Texto     │ Kontrolya                        │ —          │ 4 veces │
 │ PRODUCTO │ Texto     │ Kontrolya Facturación            │ —          │ 2 veces │
 │ Q1       │ Pregunta  │ ¿Qué sistemas utilizas hoy?      │ SISTEMA    │ @DEMO   │
 │ Q2       │ Pregunta  │ ¿Dónde nos conociste? (…)        │ ORIGEN     │ BIENV.  │
 └──────────┴───────────┴──────────────────────────────────┴────────────┴─────────┘
  «Se usa» lleva a cada lugar del texto (misma navegación que los hallazgos).
  En el editor, escribir «%» ofrece la lista (como «/» directivas y «$» patrones).
```

En el árbol: **Definición › Datos fijos (4)**, debajo de Variables. Mismo molde de modal que
`DefinitionModal.vue` y componentes nativos ([[feedback_reuse_native_chatwoot_components]]).

---

## 5. Banco de preguntas

Las preguntas son **datos fijos de tipo «pregunta»**; no hay una tercera cosa. El panel «Preguntas»
es solo un filtro de los datos fijos que muestra, por cada una:

```
 Q1 ¿Qué sistemas utilizas hoy?        guarda en SISTEMA      se hace en: @DEMO
 Q2 ¿Dónde nos conociste?              guarda en ORIGEN       se hace en: [BIENVENIDA]
 Q3 ¿Cuántos usuarios serían?          guarda en —            ⚠ no se usa en ninguna parte
```

«Se hace en» sale de buscar `%Q1%` en el texto: **cuándo** se pregunta lo dicen las rutas, que es
como el motor ya decide. El diagrama (§7) puede pintar estas preguntas dentro de la ruta.

---

## 6. La conversación llena todo, no solo el texto

Hoy la conversación devuelve `{ mensaje, instrucciones }`. Se amplía la plantilla y la respuesta:

```
 Plantilla de instrucciones iniciales            Respuesta del modelo (JSON)
 ## Quién es                                      {
 ## Qué tiene que lograr      ──► Objetivo          "mensaje": "…",
 ## Datos del negocio         ──► Contexto          "instrucciones": "…md…" | null,
 ## Lo que la gente viene a pedir ─► Rutas          "definicion": { "objetivo", "contexto" } | null,
 ## Lo que el agente recuerda ◄── nuevo ─► Variables "variables": [ {nombre, valores, inicial} ] | null,
 ## Datos fijos y preguntas   ◄── nuevo ─► Datos f.  "datos_fijos": [ {nombre, tipo, contenido, guarda_en} ] | null
 ## Reglas · Nunca · Tono                          }
```

En pantalla, mientras se conversa, a la derecha se van llenando las pestañas
**Instrucciones · Definición · Variables · Datos fijos** (la franja de avance `ProgressStrip` ya
cuenta secciones llenas; se le suman estas). Cada una se puede corregir a mano y la conversación
sigue a partir de lo corregido (igual que hoy con las instrucciones: van en cada turno).

```
 ┌── Chat ───────────────────────────┐  ┌── Lo que se va armando ─────────────────────┐
 │ Tú: vendo software de facturación │  │ [Instrucciones] [Definición] [Variables]   │
 │ y quiero agendar demos            │  │ [Datos fijos ✓4]                            │
 │                                   │  │                                             │
 │ Asistente: Entendí… Te propongo   │  │ EMPRESA   Kontrolya                         │
 │ preguntar qué sistema usan hoy    │  │ Q1  ¿Qué sistemas utilizas hoy? → SISTEMA   │
 │ (Q1) y guardarlo, así el asesor   │  │ Q2  ¿Dónde nos conociste?       → ORIGEN    │
 │ llega a la demo sabiendo…         │  │                                             │
 └───────────────────────────────────┘  └─────────────────────────────────────────────┘
```

Al dar «Crear el Entrenamiento», el redactor (`BriefComposer`) recibe Variables y Datos fijos ya
estructurados: escribe `[VARIABLES]` y `[DATOS FIJOS]` **tal cual** (no los vuelve a redactar) y
usa `%Q1%` en las rutas en lugar de copiar la pregunta. El Objetivo y el Contexto ya viajan por
`proposal`; ahora llegan desde la conversación en vez de deducirse de la ficha al final.

Riesgo conocido: el chat ya gasta hasta 12 000 tokens de salida y devuelve las instrucciones
completas cada vez. Las tres listas nuevas son cortas, pero se mide el tiempo por turno en F3
antes de darlo por bueno.

---

## 7. Diagrama y pruebas: la otra mitad de la ayuda

> Decidido 03/11/2026: **no es opcional**. Para quien no sabe de prompts, el chat *propone* y el
> diagrama *muestra* cómo funcionaría. Las dos cosas van juntas.

**Lo que ya existe** (feat/diagrama_agente_ia, dentro de esta rama): pestaña «Pruebas y diagrama»
del agente; dibuja rutas y secciones; una prueba se corre en seco o en vivo e ilumina su camino;
la pila de pruebas se guarda por agente (`tracking_test_cases`), se corre en seco al publicar, mapa
de calor, antes/ahora, «llevar al chat», comparar versiones y exportar SVG/PNG.

**Lo que se agrega:**

```
 Tú: quiero que cotice con mi hoja de precios
          │
          ▼
 Chat propone la ruta «Cotizar» ──► se crean sus pruebas solas
          │                          («cuánto cuesta la grúa», «precio en Monterrey»…)
          ▼
 Diagrama: se ilumina el camino     [BIENVENIDA] ──► @COTIZAR ──► hoja Precios
 de cada prueba, en seco              Q1 → SERVICIO   lee ZONA     → $1,800 ✓
          │
          ▼
 Chat explica: «Así contestaría tu agente: 5 de 5 pruebas llegan a Cotizar
 y encuentran el precio. Mira el camino en el diagrama.»
```

1. **Cada ruta propuesta llega con sus pruebas.** Las frases que el chat usó en `probar_ruta`
   (§12) se guardan como pruebas de esa ruta; no hay que escribirlas.
2. **El diagrama se ve junto al chat** mientras se arma (el espacio del agente ya alterna paneles:
   `leftPanel`), y se ilumina el camino de la última prueba.
3. **El diagrama muestra lo nuevo**: en cada ruta, chips de las **preguntas** que hace (`%Q1%`),
   las **variables** que lee o cambia y la **fuente** que consulta; en una prueba, el valor de cada
   variable antes y después.
4. **Si una prueba falla, el chat lo dice y propone el arreglo**, usando lo que ya existe
   («llevar al chat» con la evidencia y antes/ahora al corregir).
5. **Al crear el Entrenamiento**, las pruebas de la conversación pasan a ser la **pila del agente**
   (la misma que se corre en seco al publicar). El agente nace probado.

**El boceto (D10).** Mientras se conversa todavía no hay Entrenamiento, y el diagrama dibuja un
Entrenamiento. Propuesta: el chat guarda en la conversación las líneas `@ruta(…)` que ya probó (un
*boceto*, que el usuario no tiene que leer) y el diagrama dibuja ese boceto. Al crear el
Entrenamiento, el redactor parte de esas mismas líneas, así que el diagrama no cambia de golpe.

```
 Conversación ──► boceto (rutas probadas) ──► diagrama + pruebas en seco
       │                                            │
       └──── «Crear el Entrenamiento» ──► Entrenamiento ──► misma pila, mismo diagrama
```

---

## 8. Exportar: dos archivos, un solo menú

Un botón **«Exportar»** en el espacio del agente, con dos opciones:

| Archivo | Para qué | Qué trae |
|---|---|---|
| **Instrucciones del agente** `instrucciones_<agente>.md` | Pegarlo en ChatGPT, Claude u otra IA | Objetivo, Contexto, Variables explicadas en palabras («recuerda en qué carrera está interesado»), el Entrenamiento **con los datos fijos ya sustituidos**, y un aviso al inicio de qué partes solo funcionan dentro de la plataforma |
| **Recursos del motor** `recursos_motor_agentes_ia.md` | Saber qué puede hacer el motor (directivas, hojas, calendario…) | Lo mismo que ya descarga el Catálogo hoy |

Las directivas (`@crear_ticket`, `{{hoja:}}`…) en el archivo de instrucciones (decisión **D5**):
dejarlas tal cual con el aviso, o cambiarlas por su explicación («aquí el agente abre un caso para
una persona»). Lo segundo sirve mejor fuera, pero el archivo ya no se puede volver a importar igual.

---

## 9. Fases

```
 F0 medir ─► F1 Variables ─► F2 Datos fijos ─► FR Fuentes ─► FD Diagrama ─► F3 Conversación ─► F4 Exportar
   ½ día       formulario +     sección + %X% +   fichas +      en la          llena las 4        2 archivos
               comprobador      motor + compr.    herramientas  conversación   pestañas y
                                                  (§12)         (§7)           propone rutas
```

| Fase | Qué | Entregable que se puede probar |
|---|---|---|
| **F0** | Medir sobre los agentes reales: cuántos ya tienen `[VARIABLES]`, si alguno usa `%PALABRA%` o `[DATOS FIJOS]`, cuántas preguntas repetidas hay entre rutas | Números para cerrar D2 y para saber cuánto se gana |
| **F1** | Variables: modal, nodo en el árbol, lectura/escritura de `[VARIABLES]`, V1–V4 | Abrir un agente con variables y editarlas sin tocar el texto |
| **F2** | Datos fijos: sección, modal, `%` en el editor, `PromptConstants.expand` en los dos motores y en seco, C1–C4 | Un agente con `%EMPRESA%` contesta «Kontrolya» en vivo y en la prueba en seco |
| **FR** | Fichas de fuente + herramientas en el chat de creación (§12) | Decir «tengo una hoja de precios y quiero que cotice» y recibir la ruta propuesta, ya probada |
| **FD** | Diagrama y pruebas en la conversación (§7): boceto, pruebas de cada ruta propuesta, chips de preguntas/variables/fuente, pila al crear | Proponer «Cotizar» y verla iluminada con sus 5 pruebas; al crear el Entrenamiento, la pila ya está |
| **F3** | La conversación devuelve definición, variables y datos fijos; pestañas en vivo; el redactor los respeta | Armar un agente desde cero y ver las cuatro pestañas llenarse |
| **F4** | Menú «Exportar» con los dos archivos | Pegar el .md en ChatGPT y que se entienda solo |

Cada fase se registra en este .md al cerrarla: qué se hizo, cómo funciona, pila de pruebas y cómo
pedírselo al Asistente ([[feedback_md_por_fase]]).

---

## 10. Decisiones

> **Todas cerradas el 03/11/2026** («van todas»): se toma la propuesta de cada una.

| # | Decisión | Decidido |
|---|---|---|
| **D1** ✅ | ¿Quién sustituye los datos fijos? | **B: el motor**, antes de mandar al modelo (§4.2) |
| **D2** ✅ | Sintaxis de la referencia | `%NOMBRE%`, confirmada con la medición de F0 |
| **D3** ✅ | Nombres en pantalla | «Variables» (las del motor), «Datos fijos» (las constantes) y renombrar los `<PENDIENTE:>` de «Configurar» a «Datos por llenar» |
| **D4** ✅ | ¿Tipos de dato fijo? | texto · pregunta · liga · número; sin más hasta que haga falta |
| **D5** ✅ | Directivas en el archivo exportado | Tal cual + aviso al inicio (se puede volver a importar) |
| **D6** ✅ | ¿Pueden los datos fijos usarse en Objetivo y Contexto? | No en v1: esas dos son columnas aparte y se leen en otros lugares |
| **D7** ✅ | ¿Traer la rama `diag/asistente_agentes_ia` entera o solo sus herramientas? | **DECIDIDA 03/11/2026: opción 2, solo las herramientas**, copiadas a esta rama desde develop (§12.4) |
| **D8** ✅ | Modelo del chat de creación con herramientas | Medir en FR gpt-5.4-mini (el de hoy) contra gpt-5.5 con 3 encargos; quedarse con mini si propone bien |
| **D10** ✅ | ¿El diagrama durante la conversación? | Sí, dibujando el **boceto** de rutas ya probadas (§7) |
| **D9** ✅ | ¿Las fichas se guardan o se arman cada vez? | Se arman cada vez lo que es sin IA; solo el resumen con IA de un documento se guarda, y se rehace si el documento cambió |

---

## 11. Riesgos

- **Fuga de nombres**: si algo arma un prompt sin pasar por `expand`, el modelo ve `%Q1%`. Se
  mitiga con C1 y con una prueba que busque `%[A-Z]` en lo que sale al cliente (en el mismo
  punto donde hoy se quita la línea `VARIABLES:`, `ConversationVariables.settle`).
- **Prompts publicados**: un prompt con datos fijos que se baja a otra cuenta trae `EMPRESA` de
  la cuenta original. La pestaña «Configurar» debe ofrecer cambiarlos (encaja con F8 «Configurar
  siempre»).
- **Seguimientos con copia vieja**: cambiar un dato fijo no llega a los seguimientos ya creados
  hasta que se publique, igual que cualquier cambio del Entrenamiento hoy.
- **El chat se vuelve lento**: más estructura por turno. Se mide en F3.
- **Herramientas = más llamadas**: cada consulta a una fuente es una vuelta más del modelo. Tope
  de vueltas por turno y consumo visible por mensaje (ya existe en la rama diag, `TokenUsage`).
- **Umbral de similitud bajo en el motor** (0,20): una fuente de otro negocio «contesta» (ver FR,
  prueba real). Conviene revisarlo aparte.

---

## 12. Que el chat conozca las fuentes y proponga las rutas

### 12.1 El problema

La cuenta tiene fuentes conectadas, pero quien arma el agente no sabe **qué hay dentro** de cada
una, **qué se le puede preguntar**, ni **cómo se usa** en una ruta. El chat tampoco lo sabe: hoy
recibe solo los nombres.

```
 Lo que hoy le llega al chat de creación         Lo que necesita para proponer una ruta
 ─────────────────────────────────────────       ──────────────────────────────────────────
 ✓ Hojas de Google — Precios · Unidades          Hoja «Precios»: Servicio · Zona · Precio,
 ✓ Predefinidas (grupos) — VEN · SOP               48 filas, ej. «Plataforma | Norte | $1,800»
 ✓ Tipos de caso — Soporte · Cotización          Tipo «Cotización»: pide Nombre, Teléfono, Zona
 ✗ Sin configurar: ERP · Foro                    Grupo VEN: 12 respuestas de precios y promos
                                                 Búsqueda real de «cuánto cuesta» → qué trae
```

### 12.2 Lo que ya existe y dónde

| Pieza | Dónde está | Sirve tal cual |
|---|---|---|
| Inventario de la cuenta (`InventoryService`): fuentes, columnas de hojas, grupos de predefinidas, tipos de caso, etiquetas, frases reales de clientes | develop | Sí: es la base de las fichas |
| Catálogo de recursos (`EngineCatalog`): qué hace cada directiva y si la cuenta la tiene | develop | Sí: es el «cómo se usa» |
| Chat con herramientas (`ToolInterviewService` + `AssistantTools`): `ver_recursos`, `ver_directiva`, `ver_hoja`, `comprobar`, `probar_ruta`, `revisar_encargo` | **solo en `diag/asistente_agentes_ia`**, apagado por bandera, solo en el chat de **edición** | Casi: hay que llevarlo al chat de creación |

### 12.3 La propuesta

**A. Una ficha por fuente** (en la pestaña Recursos que ya existe, y resumida para el chat):

```
 ┌ Hoja «Precios» ─────────────────────────────────────────────────────┐
 │ Qué tiene:   Servicio · Zona · Precio · Incluye  (48 filas)         │
 │              ej. «Grúa plataforma | Norte | $1,800 | 20 km»         │
 │ Qué se le puede preguntar:  precio de un servicio en una zona;      │
 │              qué incluye un servicio                                │
 │ Cómo se usa: {{hoja_buscar: Precios | Servicio=? | Zona=? | Precio}}│
 │ Ruta sugerida:                                                      │
 │   @ruta(Cotizar #cotizacion: cuánto cuesta, precio de la grúa…):    │
 │      {{hoja_buscar: Precios | Servicio=? | Zona=? | Precio}}        │
 │                                       [Usar en una ruta ▸ al chat]  │
 └─────────────────────────────────────────────────────────────────────┘
```

| Fuente | «Qué tiene» (sin IA salvo donde se dice) |
|---|---|
| Hoja de Google | columnas y 3 filas de ejemplo |
| Documento de Google | títulos del documento; resumen corto con IA (guardado, D9) |
| Artículos | categorías y títulos |
| Predefinidas | grupos, cuántas tiene cada uno y sus títulos |
| Foro / CONTPAQi | nombre + una búsqueda de prueba bajo pedido (no se puede listar todo) |
| ERP | consultas disponibles y qué datos regresa cada una |
| Tipos de caso | campos que pide cada uno (para `@crear_ticket(asignar=…)`) |
| Calendario | qué calendarios hay y qué datos pide para agendar |
| Archivos del agente | nombre y tipo de cada archivo |

**B. Herramientas en el chat de creación.** Se llevan las de la rama diag (`ver_recursos`,
`ver_directiva`, `ver_hoja`, `probar_ruta`, `comprobar`) y se agregan dos:

- `ver_fuente(nombre)`: la ficha completa de cualquier fuente (la tabla de arriba).
- `probar_fuente(nombre, frase)`: corre la búsqueda **real** con una frase de cliente y devuelve lo
  que encontró. Así el chat comprueba que la fuente sirve **antes** de proponer la ruta.

**C. El chat propone la ruta completa y la prueba.**

```
 Tú: tengo una hoja de precios y quiero que cotice
                 │
                 ▼
  ver_fuente(Precios) ──► columnas Servicio · Zona · Precio
  probar_fuente(Precios, «cuánto cuesta la plataforma en el norte») ──► $1,800 ✓
                 │
                 ▼
  propone: frases del cliente · qué preguntar antes (%Q1%) · fuente · acción · variable
                 │
  probar_ruta(5 frases) ──► 5/5 caen en «Cotizar» ✓
                 ▼
 Asistente: Revisé tu hoja «Precios»: tiene Servicio, Zona y Precio (48 filas).
 Te propongo una ruta «Cotizar»:
   • se activa con «cuánto cuesta la grúa», «precio para Monterrey»…
   • antes pregunta qué servicio y en qué zona, si no lo dijo
   • busca en la hoja y contesta el precio exacto, con lo que incluye
 La probé con 5 frases y las 5 caen en Cotizar. ¿La agrego?
```

Lo que se propone va a las Instrucciones (en palabras simples, como hoy) y, si la persona acepta,
también a Variables y Datos fijos (§3, §4). El redactor la convierte en la línea `@ruta(…)` al
crear el Entrenamiento.

### 12.4 Cómo se trae lo de la rama diag (D7)

La rama `diag/asistente_agentes_ia` tiene 29 commits que develop no tiene, y develop le lleva
más de 250. Mezcla tres cosas: las **herramientas** (~500 líneas en 2 archivos), **cambios al motor**
(P3a: las llamadas a OpenAI ya no fallan en silencio; gpt-5 en el motor; modelo por defecto) y
**experimentos y registros** del diagnóstico.

```
 Opción 1 — traer la rama entera              Opción 2 — solo las herramientas  ★
 ──────────────────────────────────          ────────────────────────────────────────
 diag ══(rebase de 250+ commits)══► develop   develop ──► rama nueva
 − muchos choques                                  + copiar assistant_tools.rb y
 − arrastra cambios al motor sin probar              tool_interview_service.rb
   y experimentos                                  + conectarlas al chat de creación
 − un PR enorme, difícil de revisar                + ver_fuente / probar_fuente nuevas
                                              + PR chico, solo de esto
                                              − diag queda como referencia, sin mezclar
```

El arreglo **P3a** del motor (errores de OpenAI que hoy se tragan sin dejar rastro) vale la pena
por sí solo, pero es otro tema: va en su propio PR chico, aparte de este plan.

---

## 13. Avance por fase

### F0 — Medir ✅ (03/11/2026)

**Qué se hizo.** Un script de solo lectura recorrió los Agentes IA con Entrenamiento de las dos
bases que hay en este servidor: `chatwoot_dev` (24 agentes, 1 cuenta) y `chatwoot_staging_v2`
(15 agentes, 4 cuentas; en una transacción `READ ONLY`). Producción vive en otro servidor y no se
midió.

| Qué | dev (24) | staging_v2 (15) | Qué decide |
|---|---|---|---|
| Agentes con `[VARIABLES]` | 6 (25 %), todos copias del ejemplo de becas (CARRERA, SIGUIENTE_OFERTA, LIGA_ENTREGADA) | 0 | F1: casi nadie las usa porque hay que escribirlas a mano; el formulario es lo que las vuelve usables |
| Algo con forma `%PALABRA%` | 0 | 0 | **D2 confirmada**: `%NOMBRE%` está libre |
| Contexto de los «%» que sí hay | solo porcentajes («ofrece 10% de beca»): el signo nunca va pegado a una letra | — | La expresión `%[letra]…%` no los toca; C1 avisaría si algo raro aparece |
| `[DATOS FIJOS]` o `[CONSTANTES]` ya escritas | 0 | 0 | Sección libre, nada que migrar |
| Preguntas repetidas dentro de un agente | 3 agentes (12,5 %), una pregunta ×2 cada uno | 0 | El ahorro de los datos fijos no está en repetir: está en tener las preguntas **juntas y con nombre** (banco, §5) |
| Tamaño del Entrenamiento | mediana 3 437 · p90 18 593 · máx 18 738 caracteres | mediana 657 · p90 2 856 | Los agentes reales de clientes son cortos: el chat de creación tiene margen para crecer |
| Cuentas con agente que tienen alguna fuente | 1 de 1 (artículos, predefinidas, hoja, documento, CONTPAQi, foro) | 1 de 4 (artículos, predefinidas) | **FR**: 3 de 4 cuentas de staging arman agentes **sin ninguna fuente**; la ficha también tiene que decir «no tienes fuentes, así se agrega una» |

**Límite.** Muestra chica y sin producción. Si se quiere el número real, la misma consulta se puede
correr en producción en solo lectura (el script está escrito para eso).

**Agentes reales de ejemplo (03/11/2026).** El usuario pasó dos agentes de producción (en
`tmp/agentes_ejemplo/`, fuera del repo). **No son modelos de cómo debe quedar un agente**: son
la medida de la complejidad que el Asistente tiene que volver fácil (ver §14). Lo de abajo es lo
que el Asistente debe saber detectar o proponer, no un juicio sobre esos prompts:

| | «1826 Primer contacto · demostración aceptada» (DCI V8.12, 9 473 car.) | «231026 Invitación Arranque rápido distribuidores» (V1.3, 11 204 car.) |
|---|---|---|
| Variables | Declara 6 con la gramática exacta (`CIERRE_ENVIADO = NO \| SI`…) pero dentro de `[3. NÚCLEO DCI…]`, **no en `[VARIABLES]`**: el motor **no guarda ninguna**; el modelo las adivina del historial, y de `CIERRE_ENVIADO` depende todo el bloque post-cierre | Ninguna; usa etiquetas como estado. Candidatas: `PAQUETE_ENVIADO = NO \| SÍ` («si ya fue entregado, no lo repitas») y `PERMISO_FUTURO = PENDIENTE \| SÍ \| NO` |
| Preguntas | 4 «preguntas DCI literales», cada una llena un slot → banco ideal: `Q_OBJETIVO → guarda en OBJETIVO_COMERCIAL`… | 2 preguntas fijas (permiso futuro, motivo opcional) |
| Datos fijos | «Kontrolya» ×8, liga de agenda ×2, liga de precios | «Arranque rápido», fecha y horario del evento escritos **4 veces y distintos** («9:15 a. m.», «9:15am a 10:15:00 am»…), liga de Zoom ×3 |
| Lo que el Asistente debe detectar | Sin `@ruta`: el ROUTER (SOPORTE_REAL / COMERCIAL) está en prosa, así que el diagrama no tiene qué dibujar. `[9. BASE DE CONOCIMIENTO]` es justo lo que va en Definición › Contexto o en predefinidas. Usa `{Nombre}`, `{N}`, `{RESPUESTA_CORTA_INTENCION}` (llaves sencillas): confirma que `{X}` no servía para los datos fijos | El «enlace directo» y el «de registro» son **la misma URL**, aunque el texto dice que «nunca son intercambiables». El evento ya pasó (23/10) y hay que cambiar la fecha en 4 lugares. `[VALIDACIÓN ANTES DE PUBLICAR]` es una lista de pruebas **dentro del prompt** (el modelo la lee en cada mensaje): son 4 pruebas para la pestaña Pruebas. La línea de la ruta dice `evento #interesado` pero `[ETIQUETAS Y RUTAS]` dice que lleva `#evento` |

**Lo que agregan al plan:**
- **V5 (F1):** «Declaraste variables fuera de `[VARIABLES]`: el motor no las guarda» + botón «Pasarlas a Variables». Sin esto, el agente DCI no gana nada con F1.
- **C5 (F2):** dos datos fijos con el mismo contenido y distinto nombre (LIGA_DIRECTA = LIGA_REGISTRO), en ámbar.
- **FD:** detectar una lista de pruebas escrita dentro del Entrenamiento y ofrecer pasarla a la pila.
- **FR:** detectar un ROUTER en prosa y ofrecer convertirlo en `@ruta`.


### F1 — Variables ✅ (03/11/2026)

**Qué se hizo.** Un nodo **Variables** en Definición (debajo de Objetivo y Contexto) con su
modal, y el comprobador avisa lo que el motor no va a guardar.

```
 Definición del agente
 ├─ Objetivo
 ├─ Contexto
 └─ Variables ●  6 · OBJETIVO_COMERCIAL, DIMENSION, SISTEMA…     ← punto = avisos V1–V5
                 │ clic
                 ▼
 ┌ Variables ────────────────────────────────────────────────────────┐
 │ ⚠ Hay 6 variables escritas fuera de esta sección…  [Pasarlas a Variables] │
 │ Nombre             Valores posibles, separados por |              │
 │ [CIERRE_ENVIADO ]  [NO | SI                         ]  🗑         │
 │ ☐ También lo que diga el cliente     Empieza en [El primero ▾]    │
 │ [+ Agregar variable]                     [Cancelar] [Guardar]     │
 └───────────────────────────────────────────────────────────────────┘
```

**Cómo funciona.** No hay mecanismo nuevo: el modal lee y escribe la sección `[VARIABLES]` del
Entrenamiento (`agentVariables.js`, mismas reglas que `ConversationVariables::Definition`). Si no
existe la crea antes de las demás secciones; si queda vacía la quita; las notas de la sección se
conservan. Guardar sin cambiar nada no cambia el texto. «Pasarlas a Variables» saca de su sección
los renglones `NOMBRE = A | B` sueltos y los escribe uno por renglón (un renglón con varias
separadas por «;» se parte); si ya existía una con ese nombre en `[VARIABLES]`, gana esa.

Comprobador (`VariableChecks` + `StrayVariables`, ámbar, cada uno con su línea; encienden el
punto del nodo Variables):

| | Avisa |
|---|---|
| V1 | se usa `NOMBRE=…` y no está declarada |
| V2 | está declarada y ninguna regla la lee ni la cambia |
| V3 | un valor que no está en su lista (el motor lo descarta) |
| V4 | «Inicial:» con un valor fuera de la lista, o de una variable que no existe |
| V5 | declarada fuera de `[VARIABLES]` (el motor no la guarda) |

**Probado contra los agentes reales.** Los 24 de dev y los 15 de staging_v2: sin avisos falsos
(los de becas, bien escritos, salen limpios; porcentajes y ligas con `?a=b` no cuentan). Dos avisos
reales: el agente DCI (6 sueltas en `[3. NÚCLEO DCI]`) y el #10148 de dev (6 en un solo renglón
separadas por «;»). De punta a punta con el DCI: Ruby lo separa en bloques → «Pasarlas a
Variables» → Ruby lo vuelve a armar → el motor ya guarda las 6, y queda un aviso real (V2:
`AGENDA_CONFIRMADA` se declara y no se usa).

**Pila de pruebas.** Servidor: `variable_checks_spec` 13 (V1–V5, casos limpios, ámbar en el
comprobador) + 65 del comprobador y 13 de estructura sin cambios. Navegador: `agentVariables.spec`
12, `VariablesModal.spec` 6, `TrainingTree.spec` +2, `trainingSectionsMixin.spec` +1; carpeta del
Asistente 247 en verde. La prueba de calendario del comprobador (`validator_service_spec:682`) falla a
ratos desde el 15/09, sin relación.

**Cómo pedírselo al Asistente.** Todavía no: el chat aprende a proponer variables en F3. Por ahora,
desde la Estructura: «Definición › Variables».

### F2 — Datos fijos ✅ (03/11/2026)

**Qué se hizo.** Nodo **Datos fijos** en Definición (debajo de Variables) con su modal; escribir
`%` en el editor ofrece la lista; el **motor sustituye** cada `%NOMBRE%` antes de mandar el texto
al modelo; y el comprobador avisa lo que no podría sustituir.

```
 Definición del agente                 ┌ Datos fijos ─────────────────────────────────────┐
 ├─ Objetivo                           │ Nombre [EMPRESA      ]  Tipo [Texto o mensaje ▾] 🗑│
 ├─ Contexto                           │ Contenido [Kontrolya                           ] │
 ├─ Variables                          │ [%EMPRESA%] Se usa en: texto inicial, @demo      │
 └─ Datos fijos ●  3 · EMPRESA, Q1…    │──────────────────────────────────────────────────│
                                       │ Nombre [Q1  ]  Tipo [Pregunta ▾]                  │
 Editor:  «Presenta a %│»              │ Contenido [¿Qué sistema utilizas hoy?          ] │
          Datos fijos: [%EMPRESA%] [%Q1%] │ La respuesta se guarda en [SISTEMA ▾]          │
                                       └──────────────────────────────────────────────────┘
```

**Cómo se escriben** (los escribe el modal; a mano es igual):

```
[DATOS FIJOS]
EMPRESA = Kontrolya
LIGA_AGENDA (liga) = https://kontrolya.com/agenda-una-demostracion/
Q1 (pregunta) = ¿Qué sistemas utilizas hoy? → guarda en SISTEMA
CIERRE = Ahora que ya entendí lo que buscas 👌

  Puedes agendar aquí 👇 %LIGA_AGENDA%        ← sangría = sigue el mismo valor
```

**Cómo funciona el motor (D1).** `ContactTrackings::PromptConstants.expand` quita la sección, cambia
cada `%NOMBRE%` por su contenido (un dato puede citar a otro, hasta 3 vueltas; uno circular se queda
como está), cita las preguntas entre «» y convierte cada «→ guarda en» en una regla que el motor ya
entiende para Variables («Cuando el cliente conteste «…», marca SISTEMA=<lo que contestó>»). Se llama
en **un solo punto**: `ContactTracking#complementary_prompt`. Por ahí leen el texto la respuesta, el
clasificador de rutas, la prueba en seco (arma un `ContactTracking` con el borrador) y los
seguimientos. La plantilla del agente, que es lo que edita el Asistente, guarda siempre las
referencias. Las dos partes que escriben o muestran el texto de un seguimiento usan
`raw_complementary_prompt`, para no perderlas: el renombre de archivos adjuntos
(`DirectiveReferenceService`) y la API de seguimientos.

**Comprobador** (`ConstantChecks`; encienden el punto del nodo):

| | Avisa | Color |
|---|---|---|
| C1 | `%ALGO%` sin declarar (el agente lo leería literal) | rojo |
| C2 | declarado y nunca citado | ámbar |
| C3 | pregunta que guarda en una variable que no está en Variables | ámbar |
| C4 | nombre que el motor no lee («Mi empresa = …», con sugerencia `MI_EMPRESA`) o repetido | rojo |
| C5 | dos con el mismo contenido (la «liga directa» = la «de registro» del ejemplo de Invitaciones) | ámbar |

**«%» en el editor.** En el editor del Entrenamiento y en el modal de una sección, un `%` al empezar
una palabra abre la barra de datos fijos; elegir uno escribe `%NOMBRE%`. `30%` no la abre. En el
modal de ruta todavía no.

**Probado contra lo que ya existe.** 967 textos (plantillas y seguimientos de dev y staging_v2, más
los dos ejemplos): **ninguno cambia** al leerlo con el nuevo atributo, y **cero avisos falsos**.

**Pila de pruebas.** Servidor: `prompt_constants_spec` 11 (leer, sangría y párrafos, alias de tipo,
sustituir, regla de «guarda en», porcentajes, circular, atributo del modelo), `constant_checks_spec`
8 (C1–C5 y casos limpios); con el comprobador, adjuntos, seco y variables, 139 en verde; motor
(modelo, servicio de respuesta, analizador) 132 en verde. Navegador: `agentConstants.spec` 6,
`constantPicker.spec` 3, `ConstantsModal.spec` 4, árbol +1, punto +1; carpeta del Asistente 262 en verde.

**Pendiente de F2** (hecho el 03/11, ver «Pendientes chicos de F2»). Un prompt publicado con datos fijos que se baja a otra cuenta trae los de la
cuenta original: la pestaña «Configurar» todavía no ofrece cambiarlos (riesgo anotado en §11).

**Cómo pedírselo al Asistente.** Todavía no: el chat aprende a proponer datos fijos en F3. Por ahora,
desde la Estructura, «Definición › Datos fijos», o con `%` en el editor.

### FR — Fuentes: fichas y herramientas en el chat de creación ✅ código (03/11/2026)

**Qué se hizo.** Tres piezas:

1. **Ficha de cada fuente** (`SourceProfiles`, sin IA, se arma cada vez — D9): qué tiene dentro,
   qué se le puede preguntar, cómo se escribe y una ruta de ejemplo. Hojas (columnas, filas de
   ejemplo y por qué columna buscar: la de texto con más valores distintos; regresa las numéricas),
   documentos (sus partes), Centro de Ayuda (artículos publicados y categorías), predefinidas (grupos
   y códigos), foro y CONTPAQi (se consultan en vivo), tipos de caso (los campos que piden). Dice
   también qué NO tiene la cuenta.
   - Se ve en **Agentes IA › Recursos**, arriba del catálogo («Lo que tiene cada fuente»), con la
     directiva y la ruta sugerida para copiar.
   - Le llega al chat de creación **siempre**, una línea por fuente, con o sin herramientas.
2. **Herramientas** (`AssistantTools`, D7: traídas de la rama diag sin su reporte de consumo ni
   `revisar_encargo`): `ver_recursos`, `ver_fuente`, `probar_fuente` (nuevas: la ficha completa y la
   **búsqueda real** por significado en la fuente, con el umbral de la cuenta; el foro y CONTPAQi
   dicen que se consultan en vivo), `ver_directiva`, `probar_ruta` (clasificador real, 2–3 veces por
   frase) y `comprobar`. `DraftingToolLoop` las corre: hasta 8 por turno y 120 s; la misma consulta
   no se repite; si la API rechaza el razonamiento con herramientas, repite con `none`.
   `OpenaiChat#call_with_tools` traído de diag.
3. **El chat propone la ruta completa y la prueba** (reglas en `DraftingToolLoop::PROMPT`): mira la
   fuente, la prueba con frases de cliente, propone en palabras simples (frases, qué pregunta antes,
   de dónde contesta, qué hace, etiqueta), y lleva en **«boceto»** las líneas `@ruta(…)` (D10), que se
   prueban con `probar_ruta` antes de decir que funcionan. El boceto se guarda en la conversación
   (`proposal['boceto']`) y el navegador lo reenvía en cada turno; FD lo dibuja.

**Cómo se enciende.** Por cuenta, con `custom_attributes['assistant_tools'] = true`. No es una bandera
de `features.yml`: ya hay 63 y `feature_flags` es un entero de 64 bits con signo (la 64.ª se
desbordaría). Sin la bandera, el chat funciona como antes, más las fichas en sus recursos.

**Pila de pruebas.** Servidor: `source_profiles_spec` 6, `assistant_tools_spec` 8 (incluye la
búsqueda real con embedding simulado), `drafting_tool_loop_spec` 4 (corre y sigue, no repite, tope →
`none`, reintento sin razonamiento), `assistant_drafting_spec` +2 (con y sin herramientas, boceto
guardado); con Asistente y conocimiento, 127 en verde. Navegador: `SourceProfiles.spec` 2; carpeta
de Agentes IA 279 en verde (falla solo `AgentWorkspace.spec.js`, que ya falla en develop).

**Prueba real (03/11/2026, cuenta 2 de dev, gpt-5.4-mini, bandera encendida).** Tres casos, en
tres rondas, con correcciones entre ellas:

| Ronda | Cotizar con la hoja | Calificar prospectos (tipo DCI) | Psicología (sin fuente que sirva) |
|---|---|---|---|
| 1 (1 turno) | 10 s; miró la hoja y la probó; boceto bien | 18 s; probó rutas pero **no devolvió el boceto** (llegó al tope) | 10 s; **propuso las predefinidas, que son de una veterinaria** |
| 2 (1 turno, tras ajustes) | 7 s; **boceto mal escrito** (`: Precios de Articulos -> -`) | 8 s; solo preguntas (correcto en el turno 1) | 8 s; «las predefinidas y los documentos son de otro giro» ✓ |
| 3 (2 turnos) | 7 + 8 s; boceto **válido**, probó 6 y 5 frases, **todas bien**; «ya puedes crear el Entrenamiento» | 9 + 18 s; 2 rutas (calificar y soporte CONTPAQi) válidas, **6 de 6 frases bien** | — |

Lo que se corrigió por lo que se vio:
- `probar_fuente` marca `parecido_bajo` (< 0,55) y recuerda revisar si el contenido contesta y es de
  ESTE negocio; la regla 2 lo exige («la cuenta tiene material de varios negocios»).
- Si el modelo prueba rutas y no devuelve el boceto, el código guarda lo último que probó.
- **Guardia del código:** el boceto final pasa siempre por el comprobador; si el motor no lo
  ejecutaría, se le devuelven los avisos y corrige (hasta 2 vueltas).
- La sintaxis de ejemplo dice que el nombre va sin espacios, que la fuente es la directiva y que la
  ruta por defecto es una de las declaradas. Tope de herramientas: 8 → 10.

⚠ **Hallazgo del motor, no del Asistente:** con el umbral de la cuenta 2 (`similarity_threshold` 0,20),
«¿cuánto cuesta una sesión de terapia?» trae «PATITAS PRECIO CONSULTA GENERAL» (veterinaria) con 0,43
y pasa. Un agente conectado a esas predefinidas contestaría con datos de otro negocio. Lo que de verdad
contesta anda arriba de ~0,55. No se tocó el umbral: es otro tema.

**Falta.** La medición D8 (gpt-5.4-mini contra gpt-5.5); con mini, en la ronda 3 salió bien. El costo
exacto no se midió (no hay contador de consumo en develop). Las columnas de una hoja salen en el orden
de `jsonb` (Postgres no guarda el de la hoja).

**Cómo pedírselo al Asistente.** Con la bandera encendida, en «Crear desde cero»: «tengo una hoja de
precios y quiero que cotice» → revisa la hoja, la prueba y propone la ruta ya probada.

### FD — El diagrama y las pruebas en la conversación ✅ (03/11/2026)

**Qué se hizo.**

```
 ┌ Chat ───────────────────────┐  ┌ [Entrenamiento] [Rutas probadas (5)] ─────────────────┐
 │ Tú: se llama Precio Bot…    │  │ Así funcionaría tu agente                              │
 │ Asistente: Probé la ruta    │  │  Cliente ─► consultar_precios ─► Hoja Precios de Art.  │
 │ con 5 frases y las 5 cayeron│  │             ? Q1 → SISTEMA · SISTEMA   ← preguntas/vars │
 │ bien…                       │  │ Frases probadas: 5 de 5 caen siempre en la misma ruta  │
 └─────────────────────────────┘  │  ● «¿Cuánto cuesta la camisa?»   @consultar_precios    │
                                  │  ● «precio de tornillo»          @consultar_precios    │
                                  │ Al guardar el agente, estas frases pasan a su pila.    │
                                  └────────────────────────────────────────────────────────┘
```

1. **Cada ruta propuesta llega con sus pruebas.** Las frases que el chat mandó a `probar_ruta`
   (`AssistantTools#tested`) se devuelven en cada turno y se juntan en la conversación
   (`proposal['pruebas']`, máx. 30; una frase probada otra vez se queda con su último resultado).
2. **El boceto se dibuja junto al chat** (D10): pestaña «Rutas probadas» en la columna derecha
   (`DraftingSketch.vue`), que se abre sola la primera vez que llegan rutas y todavía no hay
   Entrenamiento. Usa el mismo `AgentDiagram` y la misma estructura que arma Ruby
   (`training_preview` con el texto del boceto); elegir una frase ilumina la ruta a la que cayó
   (`pathFromDryRun` con un informe que solo dice la ruta).
3. **El diagrama muestra preguntas y variables** de cada ruta (también en el agente ya guardado):
   una línea chica bajo el nodo, sacada de la línea de la ruta y de su línea de alcance
   (`routeChips`: `? Q1 → SISTEMA · SISTEMA`). Las búsquedas `{{hoja_buscar: …}}` se dibujan como
   «Hoja» (antes, «otra»).
4. **Si una prueba falla**, el chat ya lo dice y corrige (regla 5 de las herramientas; FR).
5. **El agente nace probado:** al guardar, las frases pasan a la pila (`DraftingTestCarrier`, desde
   `mark_saved!`). Con su ruta esperada si esa ruta existe en el Entrenamiento guardado; si el
   redactor la nombró distinto, como prueba propia. Sin repetidas y sin pasar el tope (40).

**Probado de verdad** (cuenta 2, un turno): 5 frases probadas, las 5 estables en
`consultar_precios_de_articulos`; el boceto se convierte en una ruta con fuente «Hoja».

**Pila de pruebas.** Servidor: `tracking_assistant_session_drafting_tests_spec` 2, `assistant_tools`
+1 (`tested`), `assistant_drafting_spec` +1 (se juntan entre turnos); con sesión y guardado, 73 en
verde. Navegador: `DraftingSketch.spec` 3, `agentDiagramLayout.spec` +3; carpeta de Agentes IA 285
en verde (falla solo `AgentWorkspace.spec.js`, de develop).

**Pendiente de D10.** ~~Que el redactor, al «Crear el Entrenamiento», parta de las líneas del boceto~~
— hecho en F3 (`BriefFromChat`).

**Cómo pedírselo al Asistente.** Con la bandera encendida, conversando: al proponer y probar una
ruta aparece la pestaña «Rutas probadas».

**Sigue:** F3 — la conversación llena Definición, Variables y Datos fijos.

### F3 — La conversación llena Definición, Variables y Datos fijos ✅ código (03/11/2026)

**Qué se hizo.**

```
 ┌ Chat ───────────────────────────┐  ┌ [Entrenamiento] [Definición y datos (3/3)] [Rutas probadas] ┐
 │ Tú: vendo software de factura-  │  │ Definición                                        Editar   │
 │ ción y quiero agendar demos     │  │  Objetivo: Calificar prospectos y agendar la demo          │
 │                                 │  │  Contexto: Kontrolya vende software…                       │
 │ Asistente: Te propongo pregun-  │  │ Variables (lo que recuerda de cada cliente)       Editar   │
 │ tar qué sistema usan hoy y      │  │  SISTEMA  CONTPAQi · Aspel · Otro                          │
 │ guardarlo, así el asesor llega  │  │ Datos fijos y preguntas                           Editar   │
 │ a la demo sabiendo…             │  │  EMPRESA  Kontrolya                                        │
 └─────────────────────────────────┘  │  Q1       «¿Qué sistemas utilizas hoy?»       → SISTEMA    │
                                      └────────────────────────────────────────────────────────────┘
```

1. **El contrato del chat creció** (`DraftingFieldsPrompt`): además de `mensaje`, `instrucciones` y
   `boceto`, el modelo devuelve `definicion {objetivo, contexto}`, `variables [{nombre, valores,
   libre, inicial}]` y `datos_fijos [{nombre, tipo, contenido, guarda_en}]`, cada uno completo
   cuando cambia y `null` si no. Las preguntas de un cuestionario se llaman Q1, Q2…
2. **Se guardan en el formato del motor** (`DraftingFields`): la Definición en `proposal.objective`
   y `proposal.ai_context` (las mismas columnas que llena el modal de Definición y que «Guardar»
   lleva al agente); Variables y Datos fijos como el TEXTO de su sección
   (`proposal.variables`, `proposal.datos_fijos`). Lo que se edita, lo que ve el modelo y lo que
   llega al Entrenamiento son exactamente lo mismo. Se limpian nombres (`Sistema actual` →
   `SISTEMA_ACTUAL`), repetidos, iniciales que no son uno de los valores (V3) y tipos raros.
3. **Pestaña «Definición y datos (N/3)»** a la derecha (`DraftingFields.vue`), visible mientras no
   hay Entrenamiento; se abre sola la primera vez que la conversación llena algo. Cada parte se
   corrige con su modal de siempre (Definición, `VariablesModal`, `ConstantsModal`); lo corregido
   se guarda sin gastar un turno (`PATCH …/drafting_chat/fields`) y viaja en el siguiente, así el
   chat sigue desde ahí.
4. **El redactor los respeta** (`BriefFromChat`): el encargo está ligado a la conversación, y
   `BriefComposer` le pasa al redactor las secciones para copiar tal cual, la orden de citar
   `%Q1%` en vez de copiar la pregunta y **el boceto de rutas probadas como base** (cierra el
   pendiente de D10: los nombres coinciden con las pruebas que van a la pila). La Definición de la
   conversación manda sobre la deducida de la ficha. Después `BriefCoverage` deja `[VARIABLES]` y
   `[DATOS FIJOS]` **exactas** (las reemplaza si el redactor las reescribió, o las agrega antes de
   la primera sección).

**Diferencias con lo planeado en §6.** La plantilla de instrucciones no ganó las secciones «Lo que
el agente recuerda» y «Datos fijos y preguntas»: van en las listas, y escribirlas dos veces
duplicaba la salida del modelo (riesgo de tiempo por turno). F4 las pondrá en el .md exportado.
La franja `ProgressStrip` no cuenta las pestañas: el contador va en la pestaña misma.

**Pila de pruebas.** Servidor: `drafting_fields_spec` 6, `brief_from_chat_spec` 6 (incluye composer
y cobertura), `drafting_chat_spec` +1, `assistant_drafting_spec` +3 (turno, PATCH, otra cuenta);
carpeta del Asistente + requests 821 en verde. Navegador: `draftingFields.spec` 3,
`DraftingFields.spec` 3; carpeta 291 en verde (falla solo `AgentWorkspace.spec.js`, de develop).

**Falta.** La prueba real (gasta OpenAI: pedir OK) — medir el tiempo por turno con las tres listas
y correr la prueba de aceptación §14.2 con los dos ejemplos.

**Cómo pedírselo al Asistente.** Conversando desde cero: «vendo software y quiero calificar
prospectos antes de mandarles la liga de la demo; pregúntales qué sistema usan». La pestaña
«Definición y datos» se va llenando.

**Sigue:** prueba real de F3 + §14.2 (con OK), luego F4 — Exportar.

### F4 — Exportar: dos archivos, un solo menú ✅ (03/11/2026)

**Qué se hizo.** Botón **«Exportar»** en la cabecera de la columna derecha (junto a «Copiar»),
visible con Entrenamiento o mientras se arma conversando (`ExportMenu.vue`, con el desplegable nativo
`WootDropdownMenu`):

```
 [Entrenamiento] …                     ✓ Sin errores  ⧉ Copiar  ⤓ Exportar ▾
                                                     ┌──────────────────────────────────────────┐
                                                     │ 📄 Instrucciones del agente (ChatGPT…)   │
                                                     │ 📘 Recursos del motor                    │
                                                     └──────────────────────────────────────────┘
```

1. **Instrucciones del agente** `instrucciones_<agente>.md` — lo arma el backend
   (`AgentExport`, `POST …/assistant/export`, no guarda nada):
   - aviso al inicio de qué solo funciona dentro del sistema (D5: directivas tal cual);
   - Objetivo y Contexto;
   - **Lo que recuerda de cada cliente**: cada variable en palabras («uno de NO o SÍ. Empieza en NO»);
   - **Entrenamiento con los datos fijos ya sustituidos** por `PromptConstants.expand`, el mismo del
     motor (el archivo dice exactamente lo que lee el modelo del sistema).
   - Sin Entrenamiento todavía: los Datos fijos en lista y las instrucciones iniciales (un nivel de
     título abajo). Así cubre lo que F3 dejó fuera de la plantilla.
2. **Recursos del motor** `recursos_motor_agentes_ia.md` — el mismo de la pestaña Recursos
   (`downloadEngineCatalog`, ahora compartido con `EngineCatalog.vue`).

**Probado con un agente real de dev** (#12877, universidad con 3 variables): sale con las variables
explicadas y el Entrenamiento completo, sin IA.

**Pila de pruebas.** Servidor: `agent_export_spec` 3, `assistant_export_spec` 1 (admin sí, agente
no). Navegador: `ExportMenu.spec` 2; carpeta 293 en verde (falla solo `AgentWorkspace.spec.js`).

**Cómo pedírselo.** En el espacio del agente: «Exportar» → «Instrucciones del agente».

**Sigue:** la prueba real (F3 + §14.2, con OK) y los pendientes chicos (Datos fijos en «Configurar»,
`%` en RouteModal, D8).

### Pendientes chicos de F2 ✅ (03/11/2026)

1. **Datos fijos en «Configurar»** (`ConstantAdaptation`): un prompt bajado de la Galería trae los
   datos fijos de su autor. Ahora salen en «Datos del negocio» como **Dato fijo**, con su valor
   actual y en cuántos lugares se cita (`%EMPRESA%`), y se cambian ahí mismo
   (`const:empresa` → `AdaptationApplier`). Solo se reescribe la declaración (con su continuación
   con sangría); el tipo y el «→ guarda en VARIABLE» se conservan.
2. **«%» en el modal de ruta**: en la línea de alcance, «%» abre la lista de datos fijos («haz
   %Q1%»), igual que en el modal de sección (mismo `ConstantPicker`).

**Pila de pruebas.** `constant_adaptation_spec` 5 (incluye inventario + aplicador + motor);
adaptación y requests 180 en verde. `RouteModal.spec` 2; carpeta 295 en verde.

**Queda:** D8 (gasta OpenAI, pedir OK) y la prueba real F3 + §14.2.

### Variables y Datos fijos como árbol ✅ (03/11/2026, pedido del usuario)

En la Estructura, «Variables» y «Datos fijos» son grupos plegables dentro de Definición, como las
Rutas: cada una en su renglón (nombre y valores, «→ VARIABLE» en las preguntas), con **Editar** y
**Eliminar** a la derecha (eliminar pide un segundo clic, «¿Eliminar?») y **+ Agregar** en la fila
del grupo. Editar o agregar abre el mismo modal de F1/F2 con un solo renglón (`focus`: índice o
`'new'`; guarda la lista completa). Las variables escritas fuera de [VARIABLES] se avisan con un
renglón ámbar que abre la lista completa con «Pasarlas». Igual en la pestaña «Definición y datos»
de la conversación. Pila: `TrainingTree.spec` (3 reescritas), `VariablesModal.spec` +2,
`ConstantsModal.spec` +1, `DraftingFields.spec` +2; carpeta 300 en verde.

---

## 14. La meta: que estos agentes se armen fácil

Los dos ejemplos marcan el techo. Quien no sabe de prompts tiene que poder llegar a un agente así
**conversando** o con el **modal de cada sección**, y también a uno sencillo si eso necesita. El
Asistente propone; la persona contesta y acepta. Siempre con los recursos que ya tiene el sistema.

### 14.1 Lo que cada ejemplo exige y cómo se vuelve fácil

| Lo que tiene el ejemplo | Cómo se lo pregunta el Asistente | Dónde queda (modal) | Recurso del sistema |
|---|---|---|---|
| **Etapas** (calificando → cierre enviado → agendado) | «¿Tu agente pasa por etapas? Por ejemplo: primero pregunta, luego manda la liga, después solo confirma» | Variables (`CIERRE_ENVIADO`) + rutas que dependen de ellas | `[VARIABLES]` guardadas por conversación |
| **Cuestionario en orden** (4 slots DCI, siempre la siguiente vacía) | «¿Qué necesitas saber del cliente antes de agendar? Te propongo 4 preguntas» | Datos fijos tipo pregunta, **en orden**, cada una «→ guarda en» su variable. El Asistente escribe solo la regla «pregunta la primera cuya variable esté vacía» | Datos fijos + Variables |
| **Mensajes exactos** (nodos de cierre y agendado, con y sin nombre) | «¿Hay mensajes que siempre deben salir igual?» | Datos fijos tipo texto; el Asistente arma la versión con nombre si lo sabe | Datos fijos |
| **Interrupciones** (pide humano o precio a media calificación) | «Si a medio cuestionario te piden hablar con alguien, ¿qué hacemos?» | Una ruta con «responde y retoma la pregunta pendiente» | Rutas + Variables |
| **Base de conocimiento** dentro del prompt | «Esta información ¿cambia seguido?» → si no, Contexto; si sí, una fuente | Definición › Contexto, o una fuente | Predefinidas, artículos, documentos y hojas (§12) |
| **Mensaje inicial de campaña** (plantilla de WhatsApp) | «¿El agente empieza la conversación o espera a que le escriban?» | Se elige la plantilla; el agente solo atiende las respuestas | Plantillas de WhatsApp y campañas |
| **Archivo adjunto** (flyer) | «¿Mandas algún archivo? Súbelo aquí» | Archivos del agente → `{{nombre}}` | Adjuntos del agente |
| **Ligas y datos del evento** repetidos | Se piden una vez | Datos fijos (`%LIGA_REGISTRO%`, `%EVENTO_FECHA%`) | Datos fijos |
| **Etiquetas de resultado** que se ponen solo en ciertos casos | «¿Qué resultados quieres poder contar o filtrar después?» | Rutas con su etiqueta; el Asistente propone las que ya existen en la cuenta | Etiquetas |
| **Excluir a quien pidió no recibir más** | «Cuando alguien diga "no me manden nada", ¿lo sacamos de las campañas?» | Se avisa qué automatización hace falta | Automatizaciones y campañas |
| **Consultas ajenas** (precios del CRM, integraciones) | «Si preguntan otra cosa, ¿de dónde contestamos?» | Ruta por defecto con su fuente, ya probada | Predefinidas, artículos (§12, `probar_fuente`) |
| **Lista de validación** escrita en el prompt | No se pide: el Asistente crea las pruebas solo | Pestaña Pruebas: pila del agente | Pruebas y diagrama (§7) |

**Lo mismo por los dos caminos.** Cada fila se puede llenar conversando *o* abriendo su modal en la
Estructura (Definición · Variables · Datos fijos · Rutas · Secciones · Archivos). El chat y los
modales escriben en el mismo lugar: lo que se cambia en uno, el otro lo ve.

**Del tamaño que haga falta.** El Asistente no empuja a la persona a un agente grande: empieza por lo
mínimo que pidió y solo pregunta por etapas, cuestionarios o interrupciones si el caso lo pide (una
invitación a un evento no necesita cuestionario; una calificación de ventas sí).

### 14.2 Prueba de aceptación

Para cada ejemplo, una **conversación guionada** como si fuera una persona sin conocimientos
técnicos («quiero calificar prospectos antes de mandarles la liga de la demo»; «quiero invitar a
mis distribuidores a una sesión por Zoom»). Al terminar:

1. El agente que sale tiene lo de la tabla: las etapas, el cuestionario, los mensajes, las ligas y
   las etiquetas que el ejemplo necesita.
2. Pasa las pruebas propias del ejemplo (las 4 de la validación de Invitaciones y otras 4
   equivalentes para DCI: dato a dato, interrupción por humano, todo en un mensaje, post-cierre
   sin preguntas).
3. La persona no escribió ni una línea de sintaxis del motor.
4. Se cuenta cuántos turnos y cuánto costó.

Esta prueba se corre al cerrar F3 y FD, y cada vez que cambie el chat.

---

## 15. Pestaña «Probar fuentes» (pedido del usuario, 04/11/2026)

**El pedido.** Una pestaña para probar las fuentes de datos del agente y validar las consultas,
viendo el umbral, parecida a «Prueba de búsqueda» de Base de Conocimiento.

**Decidido con el usuario (04/11):** va en el **espacio del agente** (junto a «Pruebas y diagrama»),
prueba **las fuentes que usa ese agente, como las buscaría él**, y cubre los cuatro tipos:
parecido, hojas, ERP y fuentes en vivo.

**Por qué no basta la de Base de Conocimiento.** Esa busca en TODAS las fuentes juntas con un umbral
que se mueve a mano (0.7 por omisión). El agente no hace eso:

| Directiva | Dónde busca | Umbral | Tope |
|---|---|---|---|
| `@buscar_predefinidas` | todas las predefinidas | el de la cuenta (0.20 por omisión) | `max_results` (3) |
| `@buscar_predefinidas(GRUPO)` | solo las que empiezan con GRUPO | **0.45** (`GROUP_SIMILARITY_THRESHOLD`) | 3 |
| `@buscar_predefinidas(!GRUPO)` | todas menos esas | el de la cuenta | 3 |
| `@buscar_articulo` | artículos | el de la cuenta | 3 |
| `{{doc:X}}`, `{{hoja:X}}` (FAQ) | esa fuente | el de la cuenta | 3 |
| `{{hoja:X}}` (modo datos) | Ruby calcula exacto (IA traduce la pregunta) | — | — |
| `{{hoja_buscar: …}}` | valor exacto en una columna | — | 20 filas |
| `{{consulta:…}}` | la consulta del ERP (IA llena los «?») | — | — |
| `@buscar_foro(X)`, `@discourse` | Discourse en vivo | — | 3 |
| `@soporte_contpaq(X)` | servicio de CONTPAQi (responde ya escrito) | — | — |

```
 [Entrenamiento] [Pruebas y diagrama] [Probar fuentes]
 Fuente: [ @buscar_predefinidas(PATITAS) — ruta dudas ▾ ]
 Frase del cliente: [ ¿cuánto cuesta la consulta?      ] [Probar]
 Umbral que usa aquí: 0.45 (grupo) · toma hasta 3
  #1 PATITAS_CONSULTA  0.71 ███████████  ✓ la usaría
  #2 PATITAS_VACUNAS   0.48 ███████      ✓ la usaría · parecido bajo
  #3 PATITAS_HORARIO   0.41 ██████       ✗ bajo el umbral
  #4 PATITAS_BAÑO      0.47 ███████      ✗ fuera del tope (solo toma 3)
```

**Fases.**
- **P1 — parecido** (predefinidas con y sin grupo, artículos, documentos, hojas FAQ): sin IA más que
  el embedding de la frase. Lista las directivas del Entrenamiento con la ruta que las usa; si el
  agente no tiene ninguna, ofrece las fuentes de la cuenta.
- **P2 — hojas y ERP**: `{{hoja_buscar:}}` (con el valor que se escribe), `{{hoja:}}` en modo
  datos y `{{consulta:}}` (gastan una llamada de IA: se avisa).
- **P3 — en vivo**: foro / `@discourse` (lista lo que regresa Discourse) y CONTPAQi (abre un hilo
  de prueba en su servicio: se avisa).


### P1 — parecido ✅ (04/11/2026)

- **Pestaña «Probar fuentes»** en el espacio del agente (solo administradores), como una vista más
  del mismo Asistente (usa el borrador abierto). `SourceProbePanel.vue`: elegir la fuente (cada
  directiva del Entrenamiento, con las rutas que la usan), escribir la frase, ver el umbral que se
  usa ahí (grupo o cuenta) y el tope, y cada resultado con su parecido, una barra con la marca del
  umbral y por qué se usaría o no («✓ la usaría», «✗ bajo el umbral», «✗ fuera del tope»,
  «parecido bajo» < 0.55). Las frases probadas quedan como atajos.
- **Igual que el motor** (`SourceProbe`): el alcance y el umbral del grupo salen de
  `KnowledgeBaseResponseService.grouped_items` / `.group_threshold` (sacados a métodos de clase;
  el motor delega en ellos), el umbral y el tope de `kbase_setting`, el embedding del mismo modelo
  (`Embedding`, ahora compartido con `probar_fuente`). Sin Google activo, o con la fuente
  inexistente, lo dice: el agente no buscaría ahí.
- **Fuente vacía**: medido en el agente real #12156 (cuenta 2), dos rutas buscan en grupos de
  predefinidas que no tienen ninguna respuesta («ADAM POLITICA SOLICITUD DE CORREO», «… MANEJO DE
  PRECIOS»). La lista los marca «vacía» y la prueba lo explica sin gastar el embedding.
- Sin directivas en el Entrenamiento, ofrece las fuentes de la cuenta.

**Pila de pruebas.** `source_probe_spec` 8 (vectores con parecido exacto: grupo, tope, umbral de
cuenta, Google, vacía, pendientes), `assistant_source_probe_spec` 2; motor de KBase y herramientas
114 en verde (los 4 fallos de `knowledge_base_controller_spec` ya estaban: 403). Navegador:
`SourceProbePanel.spec` 4; carpeta 304 en verde.

**Sigue:** P2 — `{{hoja_buscar:}}`, `{{hoja:}}` en modo datos y `{{consulta:}}`.

### P2 — hojas exactas y ERP ✅ (04/11/2026)

- **`{{hoja_buscar:}}`** (`SourceProbeExact#sheet_lookup`): `SheetLookup` con la FRASE como texto
  (los «?» salen de ella, igual que en el servicio de una cotización), **sin IA**. Dice qué buscó,
  qué regresaría y las filas (hasta 20); si la frase no trae el dato, «el agente se lo
  preguntaría»; si no hay fila, «lo diría y no inventaría»; columna o hoja inexistente, cuál.
  Probado con la hoja real del agente de grúas #10368 (7 filas para un «tipo»; sin dato →
  preguntaría «tipo»).
- **`{{hoja:X}}` en modo datos**: `SheetQueryService` (la IA traduce, Ruby calcula); muestra el
  resultado o «no pudo resolver».
- **`{{consulta:…}}`**: con «?», `AskedParams` (la IA decide si la frase la pide y llena los
  valores, con el modelo de la bandeja del agente) + `AskedRun`: muestra con qué valores corrió y
  la tabla, o «la frase no la pide»; sin «?», el render de siempre. **RFC de prueba** opcional (en
  una conversación sale de la ficha del contacto).
- La lista marca `uses_ai` (hoja en modo datos, consulta con «?») y la pantalla lo avisa antes de
  probar.

**Pila de pruebas.** `source_probe_exact_spec` 7, `source_probe_spec` +2; `ExactProbeResult.spec` 4,
`SourceProbePanel.spec` +1 (RFC e inbox); carpeta 309 en verde. El ERP no se probó contra una
conexión real.

**Sigue:** P3 — foro / `@discourse` y CONTPAQi en vivo.
