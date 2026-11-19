# frozen_string_literal: true

# Motor 2.0 — la secuencia de preguntas la manda el código (Motor2::Skills::Qualify):
#   - si el mensaje del agente no termina con la pregunta pendiente, se le pide una vez y, si
#     tampoco, se agrega tal cual;
#   - si dice que lo pasa al equipo sin haberlo calificado ni pasado (sin llamar la herramienta),
#     se le pide que lo haga o que no lo prometa;
#   - la bienvenida combinada (agentes de una función) va tal cual al inicio de la primera respuesta;
#   - si el cliente preguntó algo y contestó sin buscar (puede buscar), se le pide que busque antes:
#     así no afirma «sí lo tenemos» sin haberlo visto;
#   - si pidió una persona y ya toca pasarlo (Motor2::Skills::QualifyFlow), se pasa aunque el modelo
#     no llame la herramienta;
#   - al agregar la pregunta pendiente después de un desvío, va con la frase que conecta.
# Lo incluye Motor2::Runner (usa @mode, @decision, @skills, @trace, @welcome, #run, #clean y #unsourced?).
module Motor2::QuestionGuard
  ASK_AGAIN = 'Tu mensaje debe terminar con esta pregunta, tal cual: «%<ask>s». Reescríbelo (corto) terminando con ella.'
  PROMISE = /(pas(o|ar|aré|o) (tu|sus|la) (información|info|datos)|te (contact|escrib|llam)(a|e|ar)|un asesor te|alguien del equipo te)/i
  NO_PROMISE = 'Dijiste que lo pasas al equipo, pero no llamaste ninguna herramienta. Si ya cumple lo de «calificado», llama ' \
               'prospecto_calificado (o pasar_a_humano) y despídete; si no, no le digas que lo pasas y sigue con lo que falte.'

  # La habilidad Calificar del turno (también la usa Motor2::Skills::Handoff).
  def qualify_skill = Array(@skills).find { |s| s.key == 'qualify' }

  private

  # Las revisiones de la plática, en orden: buscó si le preguntaron, no prometió sin decidir, termina
  # con la pregunta pendiente.
  def guard_turn(messages, text)
    %i[ensure_handoff ensure_searched ensure_decision ensure_question].reduce(text) do |current, check|
      current.present? ? send(check, messages, current) : current
    end
  end

  # La secuencia de preguntas la manda el código: si no terminó con la pendiente, se le pide una vez
  # y, si tampoco, se agrega tal cual (no se queda sin preguntar).
  def ensure_question(messages, text)
    ask = pending_question
    return text if ask.blank? || Motor2::Skills::Qualify.asks?(text, ask)

    @trace.event(:revision, 'pregunta pendiente')
    messages << { role: 'assistant', content: text } << { role: 'system', content: format(ASK_AGAIN, ask: ask) }
    again = clean(run(messages))
    return again if again.present? && Motor2::Skills::Qualify.asks?(again, ask) && !unsourced?(again)

    [text, qualify_skill&.bridge, ask].compact_blank.join("\n\n")
  end

  HANDOFF_ASK = 'Pidió hablar con una persona y ya toca pasarlo: llama pasar_a_humano y despídete (en un momento lo atiende ' \
                'un asesor). No hagas más preguntas.'
  HANDOFF_TEXT = 'Claro, en un momento te atiende un asesor. ¡Gracias por tu paciencia!'

  def ensure_handoff(messages, text)
    return text unless @mode == :reply && @decision.nil? && qualify_skill&.must_handoff?

    @trace.event(:revision, 'pidió una persona: se pasa')
    messages << { role: 'assistant', content: text } << { role: 'system', content: HANDOFF_ASK }
    again = clean(run(messages))
    return again.presence || HANDOFF_TEXT if @decision

    @decision = ['handoff', 'Pidió hablar con una persona.']
    HANDOFF_TEXT
  end

  # La bienvenida de la empresa va tal cual al inicio del primer mensaje (la pone el código).
  def welcome_note
    return nil unless @welcome

    "Tu mensaje lo empieza la bienvenida de la empresa (la pone el código): «#{@welcome}». No saludes ni te presentes " \
      'otra vez: escribe solo lo que sigue (contesta lo que preguntó, si preguntó algo, y la pregunta pendiente).'
  end

  def with_welcome(text)
    return text unless @welcome

    @trace.event(:bienvenida, 'combinada con la respuesta')
    # Si el modelo la volvió a escribir (pasa aunque se le diga), se quita: va una sola vez.
    rest = text.to_s.gsub(@welcome, '').strip.sub(/\A[\s.,;:!¡]+/, '')
    [@welcome, rest].compact_blank.join("\n\n")
  end

  SEARCH_FIRST = 'El cliente preguntó algo y contestaste sin buscar. Búscalo con buscar_en_fuentes antes de contestar; ' \
                 'si no sale, no lo afirmes: dile que un asesor se lo confirma y sigue con la pregunta pendiente.'
  SEARCH_TOOLS = %w[buscar_en_fuentes buscar_en_catalogo].freeze

  def ensure_searched(messages, text)
    return text unless unsearched_question?

    @trace.event(:revision, 'contestó sin buscar')
    messages << { role: 'assistant', content: text } << { role: 'system', content: SEARCH_FIRST }
    again = clean(run(messages))
    again.present? && !unsourced?(again) ? again : text
  end

  def unsearched_question?
    @mode == :reply && @decision.nil? && @last_customer.to_s.include?('?') &&
      @skills.any? { |s| s.key == 'knowledge' } && @trace.tools.none? { |t| SEARCH_TOOLS.include?(t['name']) }
  end

  # Prometió pasarlo sin llamar la herramienta: se le pide una vez que lo haga bien.
  def ensure_decision(messages, text)
    return text unless undecided_promise?(text)

    @trace.event(:revision, 'prometió pasarlo sin calificarlo')
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_PROMISE }
    again = clean(run(messages))
    again.present? && !unsourced?(again) ? again : text
  end

  def undecided_promise?(text)
    @mode == :reply && @decision.nil? && @skills.any? { |s| s.key == 'qualify' } && text.match?(PROMISE)
  end

  # Solo al contestar y si no decidió terminar (calificar, descartar, pasar).
  def pending_question
    return nil unless @mode == :reply && @decision.nil?

    @skills.filter_map(&:required_question).first
  end
end
