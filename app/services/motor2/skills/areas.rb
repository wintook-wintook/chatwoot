# frozen_string_literal: true

# «Áreas» — lo de «Atención a clientes» que manda el código (Plan-Motor-Agentes §11.15):
#   - prepare: el clasificador (Motor2::Triage) decide el área, si es suficiente, la gestión o la severidad;
#     guarda la aclaración pendiente (continuidad) y la cola de lo demás que pidió (multi-intención);
#   - memory / turn_note: qué toca hacer en este mensaje (aclarar, contestar, levantar caso, registrar
#     la gestión, canalizar) y lo que sigue pendiente;
#   - tools: solo las del área en curso (Administrativo no busca; Comercial no levanta casos de soporte);
#   - allows_search?: sin búsqueda si falta aclarar o si el área no consulta fuentes (Motor2::Skills::Knowledge);
#   - must_handoff? / hold_handoff?: pide una persona (Motor2::ReplyChecks, Motor2::Skills::Handoff).
#
#   memoria: state['triage'] (lo de este mensaje), state['pendiente'] (aclaración), state['cola'],
#            state['handoff_area'] (a qué equipo se pasa), state['case_id']
#   Soporte con evidencia, RESUELTO / ESCALAR, fuentes y etiquetas: Motor2::Skills::SupportFlow.
class Motor2::Skills::Areas < Motor2::Skills::Base
  include Motor2::Skills::AreaActions
  include Motor2::Skills::SupportFlow
  include Motor2::Skills::AreaRules

  GESTION = { type: 'string', enum: %w[cotizacion demo visita vendedor contratar otra] }.freeze

  def self.key = 'areas'

  def on? = config.skill_on?(key) && function.respond_to?(:areas)

  def prepare(history)
    return if @turn.attempt? # recordatorio: no hay mensaje nuevo que clasificar (attempt_note)

    customer = Array(history).select { |m| m[:role].to_s == 'user' }.map { |m| m[:content].to_s }
    @human_requests = customer.count { |t| t.match?(Motor2::Skills::QualifyFlow::HUMAN) }
    @held_before = state['handoff_held']
    route_turn(customer, history)
    state['handoff_held'] = true if human? && !must_handoff? # ya se le preguntó qué necesita: la próxima, se pasa
  end

  def tools
    list = [fn('estado_caso', 'Cómo va el caso abierto del cliente (folio y estado).')]
    return list if area_key == 'none'

    list << fn('canalizar', "Pasa la plática al equipo de #{area_title}. Después escribe solo la despedida (en cuanto puedan lo atienden).",
               { motivo: STR }, %w[motivo])
    if support_case?
      list << fn('crear_caso', 'Levanta su caso de soporte. Después dale el folio.', { titulo: STR, descripcion: STR },
                 %w[titulo descripcion])
    end
    if area_key == 'sales'
      list << fn('registrar_gestion', 'Hace la gestión comercial que pidió (cotización, demo, visita, vendedor, contratar).',
                 { tipo: GESTION, detalle: STR }, %w[tipo detalle])
    end
    list
  end

  def allows_search? = sufficient? && !@resolved && !@escalate && %w[support sales none].include?(area_key)

  def memory
    lines = []
    lines << "ÁREA EN CURSO: #{area_title} — «#{now['intencion']}»#{gestion_text}" unless area_key == 'none'
    lines << system_line if area_key == 'support' && service_name
    lines << "DESPUÉS NO OLVIDES: #{queue.map { |q| "#{title_of(q['area'])}: #{q['intencion']}" }.join(' | ')}" if queue.any?
    lines.join("\n")
  end

  def turn_note
    return attempt_note if @turn.attempt?

    first = first_note
    return first if first
    return act_now_note if must_act?
    return "Falta aclarar: haz SOLO esta pregunta, sin buscar ni contestar otra cosa: «#{now['aclaracion']}»" unless sufficient?

    [clarified_note || area_note, area_rules_note, queue_note].compact.join("\n")
  end

  # Pidió una persona y ya toca pasarlo: de inmediato, si lo vuelve a pedir, o si ya se sabe qué necesita.
  def must_handoff?
    return false if @acted || !human? # ya levantó el caso o registró lo que pidió: eso ya lo atiende alguien

    function.human_now? || @held_before || (area_key != 'none' && sufficient?)
  end

  # Todavía no se sabe qué necesita: se pregunta una vez antes de pasarlo.
  def hold_handoff?
    return false unless human? && !must_handoff?

    state['handoff_held'] = true
  end

  def call(name, args)
    case name
    when 'estado_caso' then case_status
    when 'canalizar' then channel(args['motivo'])
    when 'crear_caso' then create_case(args)
    else register(args)
    end
  end

  def area_title = title_of(area_key)

  # Pidió una persona (Motor2::ReplyChecks: «te paso con…» ahí es lo esperado).
  def human_asked? = human?

  def area_key = now['area'] || 'none'

  def now = state['triage'].to_h

  private

  def function = config.function

  # RESUELTO / ESCALAR (Motor2::Skills::SupportFlow) o, si no, el clasificador.
  def route_turn(customer, history)
    keyword = keyword_turn(customer.last.to_s)
    return apply_keyword(keyword) if keyword

    classify(history) if customer.any?
  end

  # Lo que va antes que todo: pidió una persona o dijo RESUELTO / ESCALAR.
  def first_note
    return handoff_note if must_handoff?
    return 'Pidió una persona: dile que con gusto y pregúntale UNA vez qué necesita, para pasarlo al equipo correcto.' if hold_handoff_note?

    keyword_note if @resolved || @escalate
  end

  def classify(history)
    @last_ask = agent_question(history)&.dig('aclaracion') # para la revisión de lo encontrado (Motor2::ResultCheck)
    had_pending = pending_from(history)
    result = triage(history)
    return unless result

    count_turn(result['atender'])
    state['triage'] = result['atender']
    clarified! if had_pending && !sufficient?
    state['cola'] = result['pendientes']
    remember_pending
    trace.event(:area, "#{area_title}: #{now['intencion']}#{gestion_text}#{' (falta aclarar)' unless sufficient?}")
  end

  def clarified_note
    return nil unless @clarified

    "Ya aclaró lo que necesita («#{now['intencion']}»): NO preguntes más. Búscalo con buscar_en_fuentes y contesta con lo que encuentres."
  end

  # Ya se le pidió aclarar y contestó: no se le vuelve a preguntar, se busca con lo que hay.
  def clarified!
    state['triage'] = now.merge('suficiente' => true)
    @clarified = true
  end

  def pending_from(history)
    state['pendiente'] ||= agent_question(history)
    state['pendiente'].present?
  end

  # Si el agente terminó su mensaje con una pregunta (p. ej. «¿en qué sistema?», después de buscar) y el
  # cliente contestó, eso también es una aclaración: se completa lo mismo y no se vuelve a preguntar.
  def agent_question(history)
    list = Array(history)
    last_agent = list[0...-1].reverse.find { |m| m[:role].to_s == 'assistant' }&.dig(:content).to_s
    asked = last_agent[/¿[^¿?]*\?/]
    return nil unless asked && list.last && list.last[:role].to_s == 'user'

    { 'area' => now['area'], 'intencion' => now['intencion'].presence || 'lo que pidió antes', 'aclaracion' => asked }
  end

  def triage(history)
    Motor2::Triage.new(account: config.account).call(areas: function.areas, history: history, pending: state['pendiente'],
                                                     queue: queue,
                                                     about: { business: business_text, catalog: case_catalog })
  end

  def business_text = [function.answer(:business_what), function.answer(:business_who)].compact_blank.join(' — ')

  def remember_pending
    if sufficient?
      state.values.delete('pendiente')
    else
      state['pendiente'] = now.slice('area', 'intencion', 'aclaracion')
    end
  end

  def sufficient? = now.fetch('suficiente', true)

  # Cuántos mensajes lleva la misma solicitud (misma área e intención): para no pedir datos sin fin.
  def count_turn(fresh)
    same = now['area'] == fresh['area'] && now['area'] != 'none'
    state['area_turns'] = same ? state['area_turns'].to_i + 1 : 0
    state.values.delete('case_folio') unless same # el folio de esta solicitud (no se levanta dos veces)
  end

  # Ya preguntó lo que tocaba: toca actuar (una pregunta y con su respuesta se levanta o se pasa).
  # (Comercial cuenta solo para una gestión: una duda de información no se «resuelve» pasándola.)
  ENOUGH_ASKS = { 'admin' => 1, 'support' => 1, 'sales' => 1, 'other' => 0 }.freeze

  def must_act?
    return false if area_key == 'sales' && %w[info demo visita].include?(now['gestion'].to_s.presence || 'info')

    ENOUGH_ASKS.key?(area_key) && state['area_turns'].to_i >= ENOUGH_ASKS[area_key]
  end

  # Ya se le preguntó lo necesario: no más preguntas, se hace.
  def act_now_note
    what = if area_key == 'sales' then 'llama registrar_gestion con lo que ya te dijo'
           elsif support_case? then 'levanta su caso con crear_caso (con lo que ya te dijo) y dale el folio'
           else
             'llama canalizar con lo que ya te dijo'
           end
    first = area_key == 'support' ? 'primero búscalo con buscar_en_fuentes; si hay solución exacta, dale los pasos; si no, ' : ''
    "Ya tienes lo necesario: NO hagas más preguntas; #{first}#{what}."
  end

  def human? = @human_requests.to_i.positive? || now['pide_persona'] == true

  # Soporte: antes de pasarlo o levantar el caso se busca la solución en sus fuentes (lo hace el código: el
  # modelo a veces se la salta). No aplica si pidió una persona o no puede operar (urgente).
  def search_first?
    area_key == 'support' && !@escalate && @turn.find_skill('knowledge')&.searchable? && !searched_now? && !human? &&
      now['severidad'] != 1
  end

  # En este mismo mensaje (con lo último que dijo el cliente).
  def searched_now? = trace.tools.any? { |t| t['name'] == 'buscar_en_fuentes' }

  def hold_handoff_note? = human? && !must_handoff?

  def queue = Array(state['cola'])

  def case_status
    return { prueba: true, nota: 'En la prueba no hay casos reales.' } if test?

    ticket = orchestrator.find_active_ticket
    return { nota: 'No tiene casos abiertos.' } unless ticket

    { folio: ticket.try(:folio) || ticket.id, titulo: ticket.title, estado: ticket.status }
  end

  def title_of(key)
    key.to_s == 'none' ? 'su consulta' : function.area(key)&.dig('title') || key.to_s
  end

  def gestion_text
    return " (severidad #{now['severidad']})" if area_key == 'support' && now['severidad'].to_i.positive?

    now['gestion'].present? ? " (#{now['gestion']})" : ''
  end

  def handoff_note
    state['handoff_area'] = area_key unless area_key == 'none'
    'PIDIÓ HABLAR CON UNA PERSONA y ya toca: llama YA canalizar (o pasar_a_humano) y despídete diciendo que en cuanto puedan lo ' \
      'atienden. No hagas más preguntas.'
  end

  def queue_note
    return nil if queue.empty?

    'Al terminar con esto, pregúntale si seguimos con lo otro que pidió (DESPUÉS NO OLVIDES).'
  end
end
