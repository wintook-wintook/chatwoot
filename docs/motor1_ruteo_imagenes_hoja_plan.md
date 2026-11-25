# Plan — Motor 1.0: imágenes, condiciones opcionales, ruteo y mensajes seguidos

> Solo plan (25/11/2026). Rama `fix/motor_ruteo_imagenes_hoja`, desde `develop` (b322eb2c).
> Salió de pruebas con un agente de ventas de autos (inventario en Google Sheets, rutas con
> `{{hoja_buscar}}` y respuestas predefinidas), pero todos los cambios son del motor y sirven a
> cualquier agente 1.0 con rutas. Motor 2.0 no se toca.

## Regla de la rama: no afectar a los agentes que ya existen

Cada cambio es de uno de estos dos tipos:

- **Opcional (opt-in):** solo cambia algo si el agente lo pide en su prompt o su configuración. Los
  agentes que no lo usan se comportan exactamente igual.
- **General:** cambia a todos los agentes 1.0. Solo se acepta si corrige un error claro (el motor
  inventa o se equivoca de rama), se acota al caso que falla y pasa sin regresiones la corrida en
  seco de las pruebas guardadas de otros agentes (al menos AGENTE ESCUELA 1583 y Grúas) antes y
  después del cambio.

| # | Cambio | Tipo | A quién toca |
|---|---|---|---|
| M1 | El motor sabe que llegó una imagen o un video | General | Todos los 1.0 que reciben fotos |
| M6 | Condición opcional en `{{hoja_buscar}}` | Opcional | Solo a quien escriba la sintaxis nueva |
| M4 | `@buscar_predefinidas(GRUPO)` con una sola predefinida no aplica umbral | Opcional | Solo rutas que usan grupo |
| M3 | Un saludo o un mensaje después de horas no hereda la rama anterior | General, acotado | Rutas: solo saludos y pláticas retomadas |
| M5 | Plurales y sinónimos declarados para buscar en la hoja | Plurales: general, acotado · sinónimos: opcional | Columnas buscadas con `=?` / `~?` |
| M2 | Esperar y contestar juntos los mensajes seguidos | Opcional, por agente | Solo agentes que lo activen |

## M1 · Imágenes y videos

**Problema.** `ContactTrackings::AttachmentText.message_text` solo convierte en texto PDF, Excel,
Word y texto plano. Una foto sola llega al motor como mensaje vacío, el turno cae al conversacional
sin fuente y el modelo inventa (en las pruebas describió autos que no estaban en la foto).

**Cambio.** Agregar al texto del mensaje una marca fija: `[el cliente envió una imagen]` /
`[el cliente envió un video]`, junto con el texto que traiga. No se usa visión para leer la foto: el
motor no debe suponer qué hay en ella. El prompt de cada agente decide qué contestar («no puedo ver
fotografías, ¿cuál unidad te interesa?»). Si el prompt no dice nada, la regla general del motor es
no describir ni suponer el contenido de la imagen.

**Dónde.** `app/services/contact_trackings/attachment_text.rb` y el camino conversacional de
`ContactTrackingResponseAnalyzerJob`.

**Riesgo para otros agentes.** Hoy esos mensajes llegan vacíos; con la marca, el modelo sabe al
menos que hubo una imagen. No cambia mensajes con texto ni con documentos.

## M6 · Condición opcional en `{{hoja_buscar}}`

**Ya existe:** varias condiciones con `;` y el año sin unidad («del 2020 en adelante»).

**Problema.** Cada `?` es obligatorio. Con `S,P,H,S=?; MODELO>=?`, a «¿tienen SUV?» el motor pide el
año en vez de dar todas las SUV.

**Cambio.** Sintaxis nueva para un `?` opcional (propuesta: `MODELO>=?opcional`): si el cliente dio
el dato, filtra; si no, esa condición no se aplica. El `?` de siempre sigue siendo obligatorio, así
que las grúas siguen preguntando la capacidad.

**Dónde.** `sheet_lookup.rb`, `sheet_lookup/grammar.rb`, el comprobador del Asistente y su guía.

## M4 · Predefinida atada a la rama

**Problema.** `@buscar_predefinidas(GRUPO)` exige similitud mínima (`GROUP_SIMILARITY_THRESHOLD`); con
frases normales no pasa el umbral y la rama contesta con otra predefinida o con nada.

**Cambio.** Si el grupo deja **una sola** predefinida, se usa sin umbral: la rama ya decidió el tema.
Con dos o más, todo sigue igual.

**Dónde.** `KnowledgeBaseResponseService.grouped_items` / `perform_pgvector`.

## M3 · El clasificador no se pega al tema anterior

**Problema.** El prompt del clasificador dice «si el mensaje continúa un tema, conservá esa misma
rama», y el contexto son los últimos 4 mensajes sin importar cuándo se escribieron. Un «Hola, buenos
días» al día siguiente cae en la rama de la plática de ayer.

**Cambio (acotado).**
1. Si el mensaje es solo un saludo, no se aplica «conservá la rama».
2. Los mensajes de hace más de N horas (propuesta: 12) no entran al contexto del clasificador.

La regla de conservar la rama no se toca para lo demás.

**Dónde.** `branch_classifier_service.rb` y quien arma su contexto (`get_recent_context`,
`recent_context_for_branch`).

## M5 · Plurales y sinónimos en la hoja

**Problema.** «pickup», «pick-up» y «Pick Up» ya empatan; «pickups», «suvs», «picop» o «troca» no.

**Cambio.**
- (a) Plurales simples (s/es) al comparar con `=?` y `~?`.
- (b) Sinónimos declarados por agente en su prompt, por ejemplo una sección
  `[SINÓNIMOS]` con `PICK UP = picop, pik up, troca, camioneta de carga`. Sin la sección, nada cambia.
- No se tolera 1–2 letras de diferencia: con valores cortos («Rio», «Uno», «Note») confunde unos con
  otros.

**Dónde.** `sheet_numbers.rb` (`names?`), `sheet_lookup.rb` y `sheet_lookup/contains.rb`.

**Riesgo.** El plural cambia la comparación para todos: se valida que «Trabajo Social» / «servicio
social» (Universidad) y los remolques de Grúas den lo mismo que hoy.

## M2 · Mensajes seguidos, por agente

**Problema.** Cada mensaje dispara su propio análisis: «El sbaa» + «Sábado», o foto + «¿sigue
disponible?», dan dos respuestas.

**Cambio.** Opción por agente (apagada por defecto): esperar N segundos y contestar solo el último
mensaje con el texto de todos juntos. Es el mismo patrón que ya usa Motor 2.0 (`Motor2::ReplyJob`,
`Motor2::WAIT`). Los agentes que no lo activen contestan sin espera, como hoy.

**Dónde.** `Message#analyze_for_active_trackings` (el encolado), el inicio del job y la configuración
del agente.

## Cómo se prueba

1. **Línea base:** los casos de las pláticas que fallaron se guardan como pruebas del agente
   (`TrackingTestCase`) y se corre la pila **en seco** (ruta, fuente, fragmentos) en el agente y en
   AGENTE ESCUELA 1583. Los casos donde importa el texto, en vivo 3 veces.
2. **Después de cada cambio:** la misma corrida; no se mergea si cambia de ruta o de fuente una prueba
   que antes estaba bien en otro agente.
3. **Specs** de cada pieza (`sheet_lookup_spec`, `branch_classifier`, `attachment_text`, job).

## Orden de los PR

1. PR A: M1 + M6 (los dos más graves y los dos chicos).
2. PR B: M4.
3. PR C: M3.
4. PR D: M5.
5. PR E: M2.

Cada PR: specs, rubocop sin ofensas nuevas, corrida en seco de otros agentes, y tras el merge
desplegar y reiniciar Puma y Sidekiq en dev (pidiendo permiso: lo usa todo el equipo).
