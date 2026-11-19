# frozen_string_literal: true

# «Calificar» — lo que el código lleva de la plática para que el agente no se pierda (lo incluye
# Motor2::Skills::Qualify; usa #pending, #questions, #state, #config y @last_customer):
#
#   Pide una persona («Cómo platica» › human):
#     - cuántas veces lo pidió (el código lo detecta en los mensajes del cliente);
#     - con «terminar primero», al pedirlo la primera vez se anotan las que faltan (máx. 2) en
#       state['human_pending']: solo esas se hacen y luego se pasa;
#     - se pasa YA si lo pidió con «de inmediato», si lo pide otra vez, o si ya contestó esas.
#   Retomar conectando: si el cliente se desvió (preguntó algo o pidió una persona), la pregunta
#   pendiente va con una frase que conecta y dice cuántas faltan.
module Motor2::Skills::QualifyFlow
  WHO = '(una?\\s+)?(persona|humano|asesor|asesora|agente|vendedor|vendedora|ejecutivo|alguien)'
  HUMAN = Regexp.new("\\b(hablar|platicar|atender|contactar)\\w*\\s+con\\s+#{WHO}|" \
                     "\\bp[aá]s(a|e|ar|ame|ales|anos|as)\\s+(con|a)\\s+#{WHO}|\\bcomun[ií]ca(me|r|rme|nos)?\\s+con\\s+#{WHO}|" \
                     '\\b(persona|humano|asesor)\\s+real|\\bquiero\\s+(un\\s+|una\\s+)?(asesor|humano|vendedor|persona)',
                     Regexp::IGNORECASE)
  BRIDGES = ['Si te parece, seguimos: %<faltan>s y terminamos.', 'Para avanzar, %<faltan>s.',
             'Ya casi terminamos: %<faltan>s.'].freeze

  # Lo que se deduce de la plática antes de armar el prompt.
  def scan_flow(history)
    customer = Array(history).select { |m| m[:role].to_s == 'user' }.map { |m| m[:content].to_s }
    @last_customer = customer.last.to_s
    @human_requests = customer.count { |text| text.match?(HUMAN) }
    return unless @human_requests.positive? && state['human_pending'].nil?

    state['human_pending'] = pending.first(Motor2::Functions::ProspectRules::MAX_BEFORE_HUMAN).pluck(:number)
  end

  # Las que faltan en este turno: si pidió una persona (terminar primero), solo las anotadas.
  def pending_now
    list = pending
    return list unless human_requested? && state['human_pending']

    list.select { |q| Array(state['human_pending']).include?(q[:number]) }
  end

  def human_requested? = @human_requests.to_i.positive?

  # Pidió una persona y ya toca pasarlo.
  def must_handoff?
    return false unless human_requested? && config.function.respond_to?(:human_now?)

    config.function.human_now? || @human_requests >= 2 || pending_now.empty?
  end

  def handoff_note
    'PIDIÓ HABLAR CON UNA PERSONA y ya toca pasarlo: llama YA pasar_a_humano y despídete diciendo que en un momento lo ' \
      'atiende un asesor. No hagas más preguntas.'
  end

  # El modelo quiso guardar como respuesta lo que el cliente preguntó (pasa con modelos chicos).
  def its_question?(args)
    asked = Motor2::Skills::Qualify.normalize(@last_customer)
    given = Motor2::Skills::Qualify.normalize(args['respuesta'])
    @last_customer.to_s.include?('?') && given.present? && asked.include?(given)
  end

  # Con «terminar primero», la primera vez que pide una persona todavía no se pasa: faltan preguntas.
  def hold_handoff?
    human_requested? && !must_handoff?
  end

  # Se desvió: preguntó algo o pidió una persona.
  def detour? = @last_customer.to_s.include?('?') || @last_customer.to_s.match?(HUMAN)

  # «Si te parece, seguimos: solo me faltan 2 preguntas y terminamos.» (varía por turno).
  def bridge
    return nil unless detour? && pending_now.any?

    count = pending_now.size
    faltan = count == 1 ? 'solo me falta una pregunta' : "solo me faltan #{count} preguntas"
    format(BRIDGES[state.to_h.to_s.length % BRIDGES.size], faltan: faltan)
  end

  def bridge_note
    phrase = bridge
    return nil unless phrase

    "Antes de la pregunta pendiente, conecta con una frase como «#{phrase}» (con tus palabras; no la repitas igual cada vez)."
  end
end
