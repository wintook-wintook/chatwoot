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
                     "\\bp[aá]s(a|e|ar|ame|me|ales|anos|as)\\s+(con|a)\\s+#{WHO}|\\bcomun[ií]ca(me|r|rme|nos)?\\s+con\\s+#{WHO}|" \
                     '\\bcon\\s+(una?\\s+)?(persona|humano)\\b|' \
                     '\\b(persona|humano|asesor)\\s+real|\\bquiero\\s+(un\\s+|una\\s+)?(asesor|humano|vendedor|persona)',
                     Regexp::IGNORECASE)
  # Lo que el cliente pregunta o pide aunque no traiga «?» («das financiamiento», «conoces a…»).
  # Interrogativos con acento («qué», «cuánto»…: sin acento suelen ser respuesta: «que sea rojo») y verbos
  # de pregunta al inicio («das financiamiento», «tienen sedanes», «conoces a…»).
  ASKING = /\A[^[:alnum:]]*(qué|cuál|cuáles|cuánto|cuánta|cuántos|cuántas|cómo|dónde|cuándo|quién|quiénes|por\s+qué|tienen|tienes|
            hay|manejan|manejas|aceptan|dan|das|venden|vendes|puedo|pueden|puedes|me\s+das|me\s+dan|conoces|conocen|sabe|sabes|saben|
            es\s+posible|hacen|haces|incluye|cuesta|cuestan|cuanto\s+cuesta|cuanto\s+sale|cuanto\s+es)(?![[:alnum:]])/xi
  BRIDGES = ['Si te parece, seguimos: %<faltan>s y terminamos.', 'Para avanzar, %<faltan>s.',
             'Ya casi terminamos: %<faltan>s.'].freeze

  # Lo que se deduce de la plática antes de armar el prompt.
  def scan_flow(history)
    @held_before = state['handoff_held'] # ya se detuvo un pase en un turno anterior
    @agent_spoke = agent_spoke?(history)
    customer = Array(history).select { |m| m[:role].to_s == 'user' }.map { |m| m[:content].to_s }
    @last_customer = customer.last.to_s
    @human_requests = customer.count { |text| text.match?(HUMAN) }
    return unless @human_requests.positive? && state['human_pending'].nil?

    state['human_pending'] = pending.first(Motor2::Functions::ProspectRules::MAX_BEFORE_HUMAN).pluck(:number)
  end

  # Ya hubo un mensaje del agente: hay algo que retomar.
  def agent_spoke?(history) = Array(history).any? { |m| m[:role].to_s == 'assistant' }

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

    config.function.human_now? || @human_requests >= 2 || pending_now.empty? || (@held_before && detour?)
  end

  def handoff_note
    'PIDIÓ HABLAR CON UNA PERSONA y ya toca pasarlo: llama YA pasar_a_humano y despídete diciendo que en un momento lo ' \
      'atiende un asesor. No hagas más preguntas.'
  end

  # El modelo quiso guardar como respuesta lo que el cliente preguntó (pasa con modelos chicos).
  def its_question?(args)
    asked = Motor2::Skills::Qualify.normalize(@last_customer)
    given = Motor2::Skills::Qualify.normalize(args['respuesta'])
    detour? && given.present? && asked.include?(given)
  end

  # Con «terminar primero», la primera vez que quiere pasarlo todavía no se pasa: faltan preguntas.
  # La segunda vez sí (aunque el cliente lo escriba con errores: «pasme con…»).
  # En el mismo turno se detienen todos los intentos (el modelo a veces lo intenta dos veces).
  def hold_handoff?
    return true if @held_now
    return false if @held_before || !human_requested? || must_handoff?

    @held_now = state['handoff_held'] = true
  end

  # ¿El cliente preguntó o pidió algo (en vez de contestar)? Con o sin «?».
  def self.asking?(text)
    text = text.to_s
    text.include?('?') || text.include?('¿') || text.match?(HUMAN) || text.downcase.match?(ASKING)
  end

  # Preguntó algo (no es pedir una persona): para eso sí hay que buscar.
  def self.asking_info?(text) = asking?(text) && !text.to_s.match?(HUMAN)

  # Se desvió: preguntó algo o pidió una persona.
  def detour? = Motor2::Skills::QualifyFlow.asking?(@last_customer)

  # Al terminar el turno: además, lo que dijo no contestó la pregunta que se le hizo (una objeción, otro
  # tema: Motor2::AnswerCheck no dejó guardarlo, o el modelo no la guardó).
  def detour_after_turn?
    detour? || @rejected || (@just_asked && pending_now.include?(@just_asked)).present?
  end

  # «Si te parece, seguimos: solo me faltan 2 preguntas y terminamos.» (varía por turno).
  # Solo si ya había una plática que retomar (no en el primer mensaje). after_turn: con lo que pasó en el turno.
  def bridge(after_turn: false)
    return nil unless @agent_spoke && (after_turn ? detour_after_turn? : detour?) && pending_now.any?

    count = pending_now.size
    faltan = count == 1 ? 'solo me falta una pregunta' : "solo me faltan #{count} preguntas"
    format(BRIDGES[state.to_h.to_s.length % BRIDGES.size], faltan: faltan)
  end

  def bridge_note
    phrase = bridge
    return nil unless phrase

    "Antes de la pregunta pendiente, conecta con una frase como «#{phrase}» (con tus palabras, pero di el número exacto de " \
      'preguntas que faltan; no la repitas igual cada vez).'
  end
end
