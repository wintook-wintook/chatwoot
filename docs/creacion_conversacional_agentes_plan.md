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
`tmp/agentes_ejemplo/`, fuera del repo; banco de prueba de todas las fases):

| | «1826 Primer contacto · demostración aceptada» (DCI V8.12, 9 473 car.) | «231026 Invitación Arranque rápido distribuidores» (V1.3, 11 204 car.) |
|---|---|---|
| Variables | Declara 6 con la gramática exacta (`CIERRE_ENVIADO = NO \| SI`…) pero dentro de `[3. NÚCLEO DCI…]`, **no en `[VARIABLES]`**: el motor **no guarda ninguna**; el modelo las adivina del historial, y de `CIERRE_ENVIADO` depende todo el bloque post-cierre | Ninguna; usa etiquetas como estado. Candidatas: `PAQUETE_ENVIADO = NO \| SÍ` («si ya fue entregado, no lo repitas») y `PERMISO_FUTURO = PENDIENTE \| SÍ \| NO` |
| Preguntas | 4 «preguntas DCI literales», cada una llena un slot → banco ideal: `Q_OBJETIVO → guarda en OBJETIVO_COMERCIAL`… | 2 preguntas fijas (permiso futuro, motivo opcional) |
| Datos fijos | «Kontrolya» ×8, liga de agenda ×2, liga de precios | «Arranque rápido», fecha y horario del evento escritos **4 veces y distintos** («9:15 a. m.», «9:15am a 10:15:00 am»…), liga de Zoom ×3 |
| Lo que salta | Sin `@ruta`: el ROUTER (SOPORTE_REAL / COMERCIAL) está en prosa, así que el diagrama no tiene qué dibujar. `[9. BASE DE CONOCIMIENTO]` es justo lo que va en Definición › Contexto o en predefinidas. Usa `{Nombre}`, `{N}`, `{RESPUESTA_CORTA_INTENCION}` (llaves sencillas): confirma que `{X}` no servía para los datos fijos | El «enlace directo» y el «de registro» son **la misma URL**, aunque el texto dice que «nunca son intercambiables». El evento ya pasó (23/10) y hay que cambiar la fecha en 4 lugares. `[VALIDACIÓN ANTES DE PUBLICAR]` es una lista de pruebas **dentro del prompt** (el modelo la lee en cada mensaje): son 4 pruebas para la pestaña Pruebas. La línea de la ruta dice `evento #interesado` pero `[ETIQUETAS Y RUTAS]` dice que lleva `#evento` |

**Lo que agregan al plan:**
- **V5 (F1):** «Declaraste variables fuera de `[VARIABLES]`: el motor no las guarda» + botón «Pasarlas a Variables». Sin esto, el agente DCI no gana nada con F1.
- **C5 (F2):** dos datos fijos con el mismo contenido y distinto nombre (LIGA_DIRECTA = LIGA_REGISTRO), en ámbar.
- **FD:** detectar una lista de pruebas escrita dentro del Entrenamiento y ofrecer pasarla a la pila.
- **FR:** detectar un ROUTER en prosa y ofrecer convertirlo en `@ruta`.

**Siguiente:** F1 Variables (con V5).
