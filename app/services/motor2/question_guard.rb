# frozen_string_literal: true

# Motor 2.0 — la secuencia de preguntas la manda el código (Motor2::Skills::Qualify):
#   - si el mensaje del agente no termina con la pregunta pendiente, se le pide una vez (si ya la
#     contestó, que la guarde y siga) y, si tampoco, se cambia su pregunta por la pendiente con la
#     frase que conecta; nunca dos preguntas al final;
#   - la bienvenida combinada (agentes de una función) va tal cual al inicio de la primera respuesta.
# Las demás revisiones de lo que contesta están en Motor2::ReplyChecks; guard_turn las corre en orden.
# Lo incluye Motor2::Runner (usa @mode, @decision, @skills, @trace, @welcome, #run, #clean y #unsourced?).
module Motor2::QuestionGuard
  ASK_AGAIN = 'Tu mensaje debe terminar con esta pregunta, tal cual: «%<ask>s». Si el cliente YA la contestó en la plática ' \
              '(aunque sea de pasada, p. ej. «busco un sedán»), guárdala con guardar_respuesta y termina con la siguiente que ' \
              'falte. Reescríbelo corto, con una sola pregunta al final.'

  # La bienvenida ya hace una pregunta: en ese primer mensaje no se agrega otra (nunca dos preguntas).
  def welcome_asks? = @welcome.to_s.include?('?')

  # La habilidad Calificar del turno (también la usa Motor2::Skills::Handoff).
  def qualify_skill = find_skill('qualify')

  # La que lleva la plática y sabe si ya toca pasarlo con una persona: Calificar o Áreas.
  def flow_skill = qualify_skill || find_skill('areas')

  def find_skill(key) = Array(@skills).find { |s| s.key == key.to_s }

  private

  # Las revisiones de la plática, en orden: buscó si le preguntaron, no prometió sin decidir, termina
  # con la pregunta pendiente.
  def guard_turn(messages, text)
    checks = %i[ensure_handoff ensure_searched ensure_no_advisor ensure_defer ensure_decision ensure_area_action ensure_quote
                ensure_file_claim ensure_no_guessing ensure_evidence ensure_question ensure_bridge]
    text = checks.reduce(text) do |current, check|
      current.present? ? send(check, messages, current) : current
    end
    only_pending_question(text)
  end

  # La secuencia de preguntas la manda el código: si no terminó con la pendiente, se le pide una vez
  # y, si tampoco, se agrega tal cual (no se queda sin preguntar).
  def ensure_question(messages, text)
    ask = pending_question
    return text if ask.blank? || Motor2::Skills::Qualify.asks?(text, ask)

    @trace.event(:revision, 'pregunta pendiente')
    messages << { role: 'assistant', content: text } << { role: 'system', content: format(ASK_AGAIN, ask: ask) }
    again = clean(run(messages))
    ask = pending_question # pudo guardar la que faltaba: ahora toca otra (o ninguna)
    return again if usable_again?(again, ask)
    return text if ask.blank?

    # Si el modelo ya hizo otra pregunta, se cambia por la pendiente (nunca dos preguntas al final).
    phrase = qualify_skill&.bridge(after_turn: true) unless bridged?(without_last_question(text))
    [without_last_question(text), phrase, ask].compact_blank.join("\n\n")
  end

  # Retomar conectando: si no contestó la pregunta que se le hizo (preguntó otra cosa, una objeción,
  # otro tema) y el mensaje no trae ya la frase, va antes de la pregunta pendiente.
  def ensure_bridge(_messages, text)
    text = fix_missing_count(text).gsub(BRIDGE_AFTER_COMMA, '. \\1')
    phrase = qualify_skill&.bridge(after_turn: true)
    return text if phrase.blank? || bridged?(text)

    index = text.rindex('¿')
    before = text[0...index].strip.sub(/[,;:]?\s*\b(y|pero|entonces|ahora|bueno|así que|por cierto|oye|dime)?\s*[,;:]?\s*\z/i, '')
    before = "#{before}." if before.present? && !before.match?(/[.!?…)]\z/)
    [before, phrase, text[index..]].compact_blank.join("\n\n")
  end

  # Ya conecta (dice cuántas faltan o trae su propia frase) o no lleva pregunta.
  def bridged?(text) = text.match?(/\bfalta(n)?\b/i) || text.match?(OWN_BRIDGE) || text.exclude?('¿')

  # El modelo ya conectó con sus palabras: no se agrega otra frase (salía «Para seguir. Para avanzar…»).
  OWN_BRIDGE = /\b(para\s+(seguir|avanzar|continuar|ayudarte)|seguimos|sigamos|continuemos|ya\s+casi|si\s+te\s+parece)\b/i

  # «…bonito, Para avanzar…» → «…bonito. Para avanzar…» (cuando el modelo la escribe pegada).
  BRIDGE_AFTER_COMMA = /,\s+(Para avanzar|Si te parece|Ya casi terminamos|Ya casi acabamos|Solo me falta)/

  MISSING = /\b(me\s+)?falta(n)?\s+(\d+|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|algunas|unas|pocas)\s+preguntas?/i

  # Si el modelo dijo cuántas faltan, el número lo pone el código («me faltan 2» cuando faltan 3).
  def fix_missing_count(text)
    count = qualify_skill&.pending_now&.size.to_i
    return text if count.zero? || !text.match?(MISSING)

    text.sub(MISSING, count == 1 ? 'me falta una pregunta' : "me faltan #{count} preguntas")
  end

  def usable_again?(again, ask)
    again.present? && !unsourced?(again) && (ask.blank? || Motor2::Skills::Qualify.asks?(again, ask))
  end

  # Una sola pregunta al final: si trae la pendiente, se quitan las otras que el modelo agregó.
  def only_pending_question(text)
    return one_question(text) if find_skill('areas')

    ask = pending_question
    return text if ask.blank? || !Motor2::Skills::Qualify.asks?(text, ask)

    extras = text.scan(/¿[^¿?]*\?/).reject { |q| Motor2::Skills::Qualify.asks?(q, ask) }
    return text if extras.empty?

    extras.reduce(text) { |current, extra| current.sub(extra, '') }.gsub(/[ \t]{2,}/, ' ').gsub(/[ \t]+\n/, "\n").strip
  end

  # «Atención a clientes»: una sola pregunta por mensaje (la primera, que es la que importa).
  def one_question(text)
    asks = text.scan(/¿[^¿?]*\?/)
    return text if asks.size < 2

    asks.drop(1).reduce(text) { |current, extra| current.sub(extra, '') }.gsub(/[ \t]{2,}/, ' ').gsub(/[ \t]+\n/, "\n").strip
  end

  # Sin ninguna pregunta (la bienvenida ya pregunta) y sin la frase que quedó colgando («Sobre precios,»).
  def without_questions(text)
    text.to_s.gsub(/¿[^¿?]*\?/, '').gsub(/[^.!?\n]*[,:;]\s*(?=\n|\z|[[:upper:]¡])/, '').squeeze(' ').strip
  end

  def without_last_question(text)
    text.to_s.sub(/¿[^¿]*\?[\s\p{Emoji_Presentation}]*\z/, '').strip
  end

  # Solo al contestar y si no decidió terminar (calificar, descartar, pasar).
  def pending_question
    return nil unless @mode == :reply && @decision.nil?

    @skills.filter_map(&:required_question).first
  end
end
