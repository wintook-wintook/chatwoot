# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — FR: PREGUNTARLE AL MODELO CON HERRAMIENTAS
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §12.3. Un turno del chat de
# creación (DraftingChat) cuando la cuenta tiene encendidas las herramientas: el modelo
# puede pedir herramientas (AssistantTools) antes de contestar; el código las corre, le
# devuelve el resultado y el modelo sigue, hasta contestar el JSON de siempre.
#
# LOS TOPES (los del P8, rama diag/asistente_agentes_ia):
#   - MAX_TOOL_CALLS herramientas por turno y TIME_BUDGET segundos. Al llegar a
#     cualquiera se le prohíben (`tool_choice: none`): contesta con lo que ya vio.
#   - La misma consulta dos veces no se vuelve a correr: se le devuelve lo de antes.
#   - Si la API rechaza el razonamiento con herramientas (HTTP 400, medido con gpt-5.5
#     el 13/10/2026), se repite con reasoning_effort 'none'.
#
# LA GUARDIA DEL CÓDIGO: el boceto que entrega el modelo pasa SIEMPRE por el
# comprobador, lo haya pedido o no. Si el motor no lo ejecutaría (medido el 03/11/2026:
# escribió «: Precios de Articulos -> -» en vez de la directiva de la hoja), se le
# devuelven los avisos y corrige (hasta FIX_ROUNDS veces).
# ================================================================================

class ContactTrackings::Assistant::DraftingToolLoop
  MAX_TOOL_CALLS = 10
  TIME_BUDGET = 120
  # Vueltas de corrección del boceto (medido el 03/11/2026: con una no siempre alcanzó).
  FIX_ROUNDS = 2
  Tools = ContactTrackings::Assistant::AssistantTools

  # FR (crear_agente_conversando §12.3): con herramientas, conoce las fuentes antes de
  # proponer y prueba cada ruta. DraftingChat lo suma a su PROMPT; el contrato agrega "boceto".
  PROMPT = <<~PROMPT
    ═══ HERRAMIENTAS: CONOCE LAS FUENTES ANTES DE PROPONER ═══
    1. Cuando la persona diga para qué quiere el agente, mira con ver_recursos qué tiene la cuenta y
       con ver_fuente la fuente que serviría (una hoja de precios para cotizar, respuestas
       predefinidas para dudas, un tipo de caso para pasar a una persona). No preguntes lo que la
       fuente ya dice: úsalo y nómbralo («tu hoja Precios tiene Producto y Precio»).
    2. Antes de proponer una fuente para un tema, pruébala con probar_fuente con 1 o 2 frases como
       las escribiría un cliente, y LEE lo que encontró: que «pase el umbral» no basta. Si lo
       encontrado no contesta la frase, tiene parecido_bajo o es de OTRO negocio (la cuenta tiene
       material de varios negocios: un grupo de predefinidas de otro giro, una hoja ajena), no la
       propongas para ese tema: dilo («tus respuestas predefinidas son de otro negocio») y propone
       contestar con lo escrito o agregar ese contenido.
    3. Propón cada tema como una RUTA COMPLETA, en palabras simples, en "mensaje": con qué frases se
       activa, qué pregunta antes si le falta un dato, de dónde contesta (la fuente, con su nombre),
       qué hace además (abrir un caso, agendar) y con qué etiqueta. En "mensaje" y en
       "instrucciones", nada de sintaxis del motor.
    4. En "boceto" van las líneas del motor de TODAS las rutas propuestas, una por renglón, y la
       ruta por defecto. La persona no las lee: sirven para probar y para dibujar el agente. Se
       escriben así (si dudas, ver_directiva):
         @ruta(nombre_de_la_ruta #etiqueta: frase del cliente, otra frase): fuente -> acción
         @ruta_por_defecto: nombre_de_una_de_esas_rutas
       El nombre va SIN espacios ni acentos (consultar_precios, no «precios de artículos»). La fuente
       es una directiva tal cual la da ver_fuente («{{hoja_buscar: …}}», «@buscar_predefinidas(GRUPO)»),
       nunca el nombre suelto de la fuente; sin fuente, «-». La ruta por defecto es una de las rutas
       declaradas. Las frases, como las escribe un cliente.
    5. Antes de decir que una ruta funciona, pruébala con probar_ruta: 3 a 6 frases de esa ruta y
       de la que podría cruzarse, mandando en "rutas" el boceto COMPLETO. Si una cae donde no debe,
       corrige las frases de la ruta y vuelve a probar. Di en "mensaje" cuántas frases probaste y
       cuántas cayeron bien. Nunca digas que funciona si no lo probaste en este turno.
    6. Si la cuenta no tiene una fuente que sirva para lo que piden, dilo y explica que se agrega en
       Base de Conocimiento (hojas, documentos, respuestas predefinidas) o en el Centro de Ayuda.
    7. Máximo 10 herramientas por turno. No repitas una consulta que ya hiciste.

    Contesta SOLO este JSON (reemplaza al de arriba):
    {"mensaje": "…", "instrucciones": "el .md completo" | null, "boceto": "las líneas @ruta" | null}
    "boceto": null si en este turno no cambió ninguna ruta.
  PROMPT

  attr_reader :log, :last_routes

  def initialize(chat, tools, model:, max_tokens:)
    @chat = chat
    @tools = tools
    @model = model
    @max_tokens = max_tokens
    @log = []
    @seen = {}
    @effort = nil
  end

  # El JSON del contrato (Hash) o nil.
  def call(history)
    mensajes = history.dup
    respuesta = run(mensajes)
    FIX_ROUNDS.times do
      errores = respuesta && @tools.route_errors(respuesta['boceto'])
      break if errores.blank?

      mensajes << { 'role' => 'assistant', 'content' => respuesta.to_json }
      mensajes << { 'role' => 'user', 'content' => fix_request(errores) }
      respuesta = run(mensajes) || respuesta
    end
    respuesta
  end

  private

  def fix_request(errores)
    "(Revisión automática, no la escribió la persona.) El motor NO ejecutaría tu boceto:\n" \
      "#{errores.map { |e| "- #{e}" }.join("\n")}\nCorrígelo (usa ver_directiva si dudas) y devuelve el JSON completo otra vez."
  end

  def run(mensajes)
    inicio = monotonic
    loop do
      cerrar = @log.size >= MAX_TOOL_CALLS || monotonic - inicio > TIME_BUDGET
      mensaje = ask(mensajes, cerrar)
      return nil if mensaje.nil?

      pedidos = Array(mensaje['tool_calls'])
      return parse(mensaje['content']) if pedidos.empty? || cerrar

      mensajes << mensaje.slice('role', 'content', 'tool_calls')
      pedidos.each { |pedido| mensajes << answer(pedido) }
    end
  end

  def ask(mensajes, cerrar)
    args = { tools: Tools.definitions, model: @model, max_tokens: @max_tokens,
             tool_choice: cerrar ? 'none' : 'auto' }
    mensaje = @chat.call_with_tools(mensajes, **args, reasoning_effort: @effort)
    return mensaje unless mensaje.nil? && @effort.nil? && @chat.last_error.to_s.include?('reasoning_effort')

    @effort = 'none'
    @chat.call_with_tools(mensajes, **args, reasoning_effort: @effort)
  end

  # El mensaje `tool` con el resultado; la misma consulta repetida no se vuelve a correr.
  def answer(pedido)
    nombre = pedido.dig('function', 'name').to_s
    argumentos = pedido.dig('function', 'arguments').to_s
    clave = "#{nombre} #{argumentos}"
    resultado = @seen[clave] ||= @tools.run(nombre, argumentos)
    @log << { 'herramienta' => nombre, 'argumentos' => argumentos.truncate(200) }
    remember_routes(nombre, argumentos)
    { 'role' => 'tool', 'tool_call_id' => pedido['id'], 'content' => resultado }
  end

  # Las rutas que se probaron: si el modelo se olvida de devolver el boceto (medido el
  # 03/11/2026: llegó al tope y contestó sin él), el boceto es lo último que probó.
  def remember_routes(nombre, argumentos)
    return unless %w[probar_ruta comprobar].include?(nombre)

    rutas = JSON.parse(argumentos.presence || '{}')['rutas']
    @last_routes = rutas if rutas.present?
  rescue JSON::ParserError
    nil
  end

  def parse(content)
    return nil if content.blank?

    JSON.parse(content)
  rescue JSON::ParserError
    nil
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
