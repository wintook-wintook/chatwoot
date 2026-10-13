# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL ASISTENTE CON HERRAMIENTAS (P8, prototipo)
# ================================================================================
# El mismo turno que InterviewService —entrevista, redacción y edición, con sus tres
# bucles de corrección y su guardia—, con UNA diferencia: cada vez que le pregunta al
# modelo, el modelo puede pedir herramientas (AssistantTools) antes de contestar. El
# código las corre, le devuelve el resultado y el modelo sigue, hasta contestar.
#
# POR QUÉ HEREDA Y NO SE ESCRIBE APARTE: la guardia del código (comprobador, prueba de
# rutas, restaurar lo no pedido) tiene que correr SIEMPRE, la use o no el modelo. Es la
# misma; solo cambia cómo se le pregunta.
#
# Detrás de la bandera `assistant_tools` (solo la cuenta 2) y solo en el chat de
# edición (ver InterviewTurn). Plan: docs/diagnostico_asistente_agentes_ia_plan.md, P8.
#
# LOS TOPES (riesgos 1 y 2 del plan):
#   - MAX_TOOL_CALLS herramientas por pregunta al modelo, y el presupuesto de tiempo del
#     turno. Al llegar a cualquiera de los dos se le prohíben (`tool_choice: none`):
#     tiene que contestar con lo que ya vio.
#   - La misma consulta dos veces no se vuelve a correr: se le devuelve lo de antes.
# ================================================================================

class ContactTrackings::Assistant::ToolInterviewService < ContactTrackings::Assistant::InterviewService
  # Decisión D8 (13/10/2026, Paso 2 del P8): gpt-5.5 fue el único que hizo bien T2–T5;
  # gpt-5.4-mini se descartó (dos veces hizo la mitad y dijo que estaba completo).
  # gpt-4o queda como referencia.
  MODELS = %w[gpt-5.5 gpt-4o].freeze
  DEFAULT_MODEL = 'gpt-5.5'
  MAX_TOOL_CALLS = 8
  # Incluye lo que gpt-5 razona antes de contestar, más un Entrenamiento largo entero.
  MAX_OUTPUT_TOKENS = 16_000
  Tools = ContactTrackings::Assistant::AssistantTools
  Pieces = ContactTrackings::Assistant::DraftPieces

  PROMPT = <<~PROMPT.freeze
    ═══ HERRAMIENTAS ═══
    Tienes herramientas para CONSULTAR la cuenta y PROBAR antes de contestar. Úsalas: no adivines.
    1. Si agregas o cambias una @ruta, antes de entregar usa probar_ruta con 3 a 6 frases como las
       escribiría un cliente —de esa ruta y de la ruta con la que podría cruzarse—, mandando en
       `cambio` la línea completa nueva. Si alguna cae donde no debe, corrige y vuelve a probar.
    2. Nunca digas que algo quedó arreglado o que funciona si no lo probaste en este turno.
    3. Si una ruta usa una hoja, mírala con ver_hoja y usa sus valores reales (productos, planes,
       nombres) en las frases de esa ruta.
    4. Antes de proponer o agregar una regla, busca si el Entrenamiento ya la tiene. Si ya está y no
       se cumplió, dilo así: el problema no es que falte.
    5. Si dudas cómo se escribe una directiva o qué necesita, usa ver_directiva; para los nombres
       exactos de la cuenta, ver_recursos.
    6. Si cambiaste algo, pásalo por comprobar antes de entregar.
    7. Máximo #{MAX_TOOL_CALLS} herramientas por turno.
    8. Al editar, llena "toca" con cada pieza que cambiaste, como piden las instrucciones de edición.
    9. AL EDITAR, ENTREGA SOLO LO QUE CAMBIA. Esto reemplaza lo que se dice arriba sobre devolver el
       Entrenamiento completo:
         "entrenamiento": null
         "piezas": [cada pieza que cambias o agregas, COMPLETA y como queda: una línea @ruta(…)
                    entera, o una [SECCIÓN] con todo su texto]
         "quitar": [las piezas que se borran, ej. "@ruta(nombre)" o "[SECCIÓN]"]
       El código las pone en su lugar; lo que no mandes queda exactamente igual. La pieza que
       probaste va en "piezas" tal cual la probaste. Si solo preguntas o explicas, "piezas": [].
    10. Al entregar un cambio, en "mensaje" explica en 1 a 3 frases qué hiciste y por qué. NO listes
       las frases probadas ni los cambios: el código agrega abajo lo que de verdad probaste y la
       pantalla muestra los cambios. En "pendiente" (lista) lo que la persona tenga que decidir o
       completar; [] si no hay nada.
  PROMPT

  # Al crear desde un encargo (Paso 3.3): lo que tiene que cuidar además.
  CREATE_PROMPT = <<~PROMPT
    ═══ AL CREAR DESDE UN ENCARGO ═══
    a) Antes de entregar, usa revisar_encargo con lo que llevas escrito. Pon cada cosa que falte en
       su lugar (un dato duro, como un teléfono de emergencia, va en la ruta o la sección donde se
       usa, tal cual). No entregues mientras falte algo, salvo que no quepa: entonces dilo en
       "pendiente".
    b) Prueba con probar_ruta las rutas que se cruzan fácil, sobre todo las delicadas (crisis,
       quejas): frases ambiguas de otras rutas no deben caer ahí.
    c) La @ruta_por_defecto es la que CONTESTA (informa), nunca una que abre un caso. Ojo con la regla
       del motor: una ruta SIN fuente con flecha («: - -> @crear_ticket(…)») abre el caso PRIMERO, antes
       de contestar. Una ruta que contesta con lo escrito va sin flecha: «@ruta(…): -». Si además
       hace falta derivar lo que no se pueda resolver, eso va en otra ruta o en la prosa. Si comprobar
       avisa que esa ruta «no consulta ninguna fuente», en la ruta por defecto déjala así (es a
       propósito) y explícalo en "pendiente".
    d) Al crear, "piezas" lleva TODAS las piezas del Entrenamiento: no hay uno anterior. Por lo mismo,
       en probar_ruta el `cambio` lleva TODAS las líneas @ruta y la @ruta_por_defecto: el clasificador
       elige entre las rutas que le mandas, y una prueba con algunas no vale para el agente completo.
    e) Una fuente de la cuenta (respuestas predefinidas, foro, hoja, documento) solo si es de ESTE
       negocio: la cuenta tiene material de otros negocios. @buscar_predefinidas siempre con el grupo
       de este negocio; si no hay uno, la ruta contesta con lo escrito ("-") y lo dices en "pendiente".
  PROMPT

  # Cuánto razona gpt-5 (D16, medido el 13/10/2026). nil = el de por defecto del modelo.
  # ⚠ Con herramientas, /v1/chat/completions solo acepta 'none' para gpt-5.5 (HTTP 400:
  # «Function tools with reasoning_effort are not supported … set reasoning_effort to
  # 'none'»). Otro nivel pide la API /v1/responses.
  #   crear desde un encargo: 'none' — 47–53 s y la misma calidad (3 corridas de la T1)
  #                           contra 155–233 s con el de por defecto.
  #   editar:                 el de por defecto — con 'none' no fue más rápido (32–48 s
  #                           contra 21–44 s) y acertó menos en la T3 (1 de 2).
  EFFORTS = %w[none].freeze
  CREATE_EFFORT = 'none'

  # model: uno de MODELS; cualquier otro valor cae al de por defecto.
  # brief: el encargo del que se crea el agente (solo al crear desde un encargo).
  # effort: uno de EFFORTS, para medir; nil = el del modelo.
  def initialize(account, model: nil, brief: nil, effort: nil, **opciones)
    super(account, **opciones)
    @model = MODELS.include?(model) ? model : DEFAULT_MODEL
    @effort = EFFORTS.include?(effort) ? effort : (CREATE_EFFORT if brief)
    @brief = brief
    @tools = Tools.new(account, draft: current_draft, inbox: inbox, usage: @chat.usage, brief: brief)
    @tool_log = []
    @seen = {}
    @tested = Set.new
    @report = ContactTrackings::Assistant::ToolTurnReport.new
  end

  # Con qué herramientas, en qué orden, y con qué modelo: para la comparación (Paso 2).
  def usage = super.merge('herramientas' => @tool_log, 'modelo_prototipo' => @model, 'razonamiento_pedido' => @effort).compact

  private

  # El de InterviewService (ya memorizado allá) más cómo usar las herramientas.
  def system_prompt
    [super, PROMPT, (CREATE_PROMPT if @brief)].compact.join("\n\n")
  end

  # La pregunta al modelo, con herramientas: pide, se corre, sigue. Devuelve el JSON del
  # contrato (lo mismo que InterviewService#ask) o nil.
  def ask(history)
    mensajes = history.dup
    usadas = 0
    loop do
      cerrar = usadas >= MAX_TOOL_CALLS || !within_budget?
      mensaje = @chat.call_with_tools(mensajes, tools: Tools.definitions(brief: @brief.present?), model: @model,
                                                max_tokens: MAX_OUTPUT_TOKENS, tool_choice: cerrar ? 'none' : 'auto',
                                                reasoning_effort: @effort)
      return nil if mensaje.nil?

      pedidos = Array(mensaje['tool_calls'])
      return finished(with_tested(without_markers(with_pieces(parse_reply(mensaje['content']), history)))) if pedidos.empty? || cerrar

      mensajes += [mensaje.slice('role', 'content', 'tool_calls')]
      pedidos.each do |pedido|
        usadas += 1
        mensajes += [{ role: 'tool', tool_call_id: pedido['id'], content: run_tool(pedido) }]
      end
    end
  end

  def run_tool(pedido)
    nombre = pedido.dig('function', 'name').to_s
    argumentos = pedido.dig('function', 'arguments').to_s
    @tool_log << nombre
    remember_tested(argumentos)
    clave = [nombre, argumentos]
    return { repetida: 'ya hiciste esta misma consulta en este turno', resultado: JSON.parse(@seen[clave]) }.to_json if @seen.key?(clave)

    etapa = Tools::STAGES.fetch(nombre, :writing)
    progress(etapa)
    @seen[clave] = @tools.run(nombre, argumentos).tap do |resultado|
      @report.record(nombre, argumentos, resultado, texto: tested_text(argumentos))
      progress(etapa)
    end
  end

  # En vivo (Paso 3.2): lo que ya corrió viaja con CADA aviso de etapa —también los de
  # la guardia—, y la pantalla lo muestra debajo de la etapa (ver ToolTurnReport).
  def progress(stage, **info)
    super(stage, **info, steps: @report.steps.presence)
  end

  # Los campos del prototipo, ya usados. Si quedaran, ReplyParser.with_extras pega al
  # mensaje todo texto de un campo que no conoce: la pieza aparecía al final del chat.
  CONSUMED_KEYS = %w[piezas quitar pendiente].freeze
  def finished(reply)
    with_report(reply)&.except(*CONSUMED_KEYS)
  end

  # El reporte fijo del turno (Paso 3.1), solo cuando entrega un cambio.
  def with_report(reply)
    return reply if reply.blank? || reply['entrenamiento'].blank?

    reply.merge('mensaje' => @report.message(reply['mensaje'], reply['pendiente'], final: reply['entrenamiento']))
  end

  def tested_text(argumentos)
    texto = @tools.apply(JSON.parse(argumentos.presence || '{}')['cambio'])
    texto.is_a?(String) ? texto : nil
  rescue JSON::ParserError
    nil
  end

  # Lo que el modelo PROBÓ con una herramienta no es un cambio a escondidas: cuenta como
  # declarado en "toca" aunque se haya olvidado de nombrarlo. Medido el 13/10/2026 con
  # gpt-5.4-mini: arregló el cruce de Kontrolya y lo probó, pero no llenó "toca"; la
  # guardia de edición se lo devolvió como cambio no pedido y el modelo deshizo el arreglo.
  def remember_tested(argumentos)
    cambio = JSON.parse(argumentos.presence || '{}')['cambio']
    return if cambio.blank?

    @tested.merge(Pieces.new(cambio).pieces.keys - [Pieces::PREAMBLE_KEY])
  rescue JSON::ParserError
    nil
  end

  # ── entregar solo las piezas (P5 mínimo, adelantado al prototipo el 13/10/2026) ──
  # Reescribir los 15.000 caracteres para cambiar una línea es donde fallaba: rutas
  # duplicadas, marcadores copiados, choques con la guardia. El modelo manda las piezas;
  # se ponen sobre el Entrenamiento más reciente del turno (el de la última vuelta de
  # corrección, o el de la pantalla). Si igual mandó el texto completo, se respeta.
  def with_pieces(reply, history)
    return reply if reply.blank? || reply['entrenamiento'].present?

    piezas, claves = delivered_pieces(reply)
    return reply if claves.empty?

    reply.merge('entrenamiento' => Pieces.restore(theirs: latest_draft(history), mine: piezas, keys: claves),
                'toca' => Array(reply['toca']) | claves)
  end

  # El texto de las piezas y TODAS las claves que cambian: las que trae y las que quita
  # (una clave que no está en el texto se borra, ver DraftPieces.restore).
  def delivered_pieces(reply)
    piezas = Array(reply['piezas']).map(&:to_s).compact_blank.join("\n")
    quitar = Array(reply['quitar']).map { |k| Pieces.normalize_key(k) }.compact_blank
    [piezas, (Pieces.new(piezas).pieces.keys - [Pieces::PREAMBLE_KEY]) | quitar]
  end

  # El último Entrenamiento que el modelo vio en el hilo (la vuelta de corrección se lo
  # muestra como {mensaje, entrenamiento}), o el de la pantalla.
  def latest_draft(history)
    history.reverse_each do |m|
      next unless (m[:role] || m['role']).to_s == 'assistant'

      texto = draft_in(m[:content] || m['content'])
      return texto if texto.present?
    end
    current_draft.to_s
  end

  def draft_in(content)
    JSON.parse(content.to_s)['entrenamiento'].to_s
  rescue JSON::ParserError, TypeError
    nil
  end

  def with_tested(reply)
    return reply if reply.blank? || @tested.empty? || reply['entrenamiento'].blank?

    reply.merge('toca' => Array(reply['toca']) | @tested.to_a)
  end

  # El prompt de edición le muestra el Entrenamiento entre <<<ENTRENAMIENTO y
  # ENTRENAMIENTO>>> (EditingInstructions); gpt-5.4-mini copió el de cierre como una
  # línea más (13/10/2026). Solo se quitan si quedaron al principio o al final.
  MARKER_RE = /\A\s*<<<ENTRENAMIENTO[ \t]*\n|\n[ \t]*ENTRENAMIENTO>>>\s*\z/
  def without_markers(reply)
    return reply if reply.blank? || reply['entrenamiento'].blank?

    reply.merge('entrenamiento' => reply['entrenamiento'].gsub(MARKER_RE, ''))
  end

  def parse_reply(content)
    return nil if content.blank?

    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error("[Asistente/herramientas] respuesta no es JSON: #{e.message}")
    nil
  end
end
