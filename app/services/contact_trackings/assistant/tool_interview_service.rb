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

  # model: uno de MODELS; cualquier otro valor cae al de por defecto.
  def initialize(account, model: nil, **opciones)
    super(account, **opciones)
    @model = MODELS.include?(model) ? model : DEFAULT_MODEL
    @tools = Tools.new(account, draft: current_draft, inbox: inbox, usage: @chat.usage)
    @tool_log = []
    @seen = {}
    @tested = Set.new
    @probes = {}
    @check = nil
  end

  # Con qué herramientas, en qué orden, y con qué modelo: para la comparación (Paso 2).
  def usage = super.merge('herramientas' => @tool_log, 'modelo_prototipo' => @model)

  private

  # El de InterviewService (ya memorizado allá) más cómo usar las herramientas.
  def system_prompt
    [super, PROMPT].join("\n\n")
  end

  # La pregunta al modelo, con herramientas: pide, se corre, sigue. Devuelve el JSON del
  # contrato (lo mismo que InterviewService#ask) o nil.
  def ask(history)
    mensajes = history.dup
    usadas = 0
    loop do
      cerrar = usadas >= MAX_TOOL_CALLS || !within_budget?
      mensaje = @chat.call_with_tools(mensajes, tools: Tools.definitions, model: @model,
                                                max_tokens: MAX_OUTPUT_TOKENS, tool_choice: cerrar ? 'none' : 'auto')
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

    progress(Tools::STAGES.fetch(nombre, :writing))
    @seen[clave] = @tools.run(nombre, argumentos).tap { |resultado| remember_result(nombre, resultado) }
  end

  # Lo último que de verdad corrió: cada frase con su ruta, y el comprobador. Con esto se
  # arma el reporte del turno (with_report), no con lo que el modelo diga que probó.
  def remember_result(nombre, resultado)
    datos = JSON.parse(resultado)
    remember_probes(datos) if nombre == 'probar_ruta'
    @check = datos if nombre == 'comprobar' && datos.is_a?(Hash) && datos.key?('ejecuta')
  rescue JSON::ParserError
    nil
  end

  def remember_probes(datos)
    Array(datos).each { |p| @probes[p['frase']] = p if p.is_a?(Hash) && p['frase'] }
  end

  # ── el reporte del turno (Paso 3.1): siempre el mismo formato ──────────────────
  # El mensaje del modelo (qué hizo y por qué) + «Qué probé», armado con lo que corrió,
  # + «Pendiente». Los cambios no se repiten: la pantalla ya los muestra (ChangeList).
  # Los campos del prototipo, ya usados. Si quedaran, ReplyParser.with_extras pega al
  # mensaje todo texto de un campo que no conoce: la pieza aparecía al final del chat.
  CONSUMED_KEYS = %w[piezas quitar pendiente].freeze
  def finished(reply)
    with_report(reply)&.except(*CONSUMED_KEYS)
  end

  def with_report(reply)
    return reply if reply.blank? || reply['entrenamiento'].blank?

    partes = [reply['mensaje'].to_s.strip, probes_report, pending_report(reply['pendiente'])]
    reply.merge('mensaje' => partes.compact_blank.join("\n\n"))
  end

  def probes_report
    lineas = @probes.values.map { |p| probe_line(p) }
    lineas << report_t(@check['ejecuta'] ? 'checker_ok' : 'checker_blocking', count: Array(@check['bloqueantes']).size) if @check
    lineas = [report_t('nothing')] if lineas.empty?
    "**#{report_t('tested')}**\n#{lineas.map { |l| "- #{l}" }.join("\n")}"
  end

  def probe_line(probe)
    datos = { phrase: probe['frase'], route: probe['cae_en'], times: probe['veces'] }
    return report_t('stable', **datos) unless probe['estable'] == false

    report_t('unstable', **datos, others: Array(probe['a_veces_en']).join(', '))
  end

  def pending_report(pendiente)
    lista = Array(pendiente).map(&:to_s).compact_blank
    return nil if lista.empty?

    "**#{report_t('pending')}**\n#{lista.map { |l| "- #{l}" }.join("\n")}"
  end

  def report_t(key, **args)
    I18n.t("tracking_assistant.tools_report.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
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
