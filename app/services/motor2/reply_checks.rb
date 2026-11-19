# frozen_string_literal: true

# Motor 2.0 — revisiones de lo que contesta el agente antes de mandarlo (lo incluye Motor2::Runner;
# las corre Motor2::QuestionGuard#guard_turn, en orden):
#   - si pidió una persona y ya toca pasarlo (Motor2::Skills::QualifyFlow), se pasa aunque el modelo
#     no llame la herramienta;
#   - si el cliente preguntó algo y contestó sin buscar (puede buscar), se le pide que busque antes:
#     así no afirma «sí lo tenemos» sin haberlo visto;
#   - con «no encontró → sin prometer asesor» (Atención a prospectos), si promete que un asesor lo
#     confirma, se le pide quitarlo y, si insiste, el código quita esa frase;
#   - si dice que lo pasa al equipo sin haberlo calificado ni pasado (sin llamar la herramienta),
#     se le pide que lo haga o que no lo prometa.
# Usa @mode, @decision, @skills, @trace, @config, @last_customer, #run, #clean, #unsourced? y #qualify_skill.
module Motor2::ReplyChecks
  PROMISE = /(pas(o|ar|aré|o) (tu|sus|la) (información|info|datos)|te (contact|escrib|llam)(a|e|ar)|un asesor te|alguien del equipo te)/i
  NO_PROMISE = 'Dijiste que lo pasas al equipo, pero no llamaste ninguna herramienta. Si ya cumple lo de «calificado», llama ' \
               'prospecto_calificado (o pasar_a_humano) y despídete; si no, no le digas que lo pasas y sigue con lo que falte.'

  private

  # La frase (o el «, pero …» de una frase) que promete que un asesor lo confirma.
  ADVISOR = /(,?\s*\b(pero|y|aunque)\s+)?[^.!?¡¿\n,]*\b(asesor|asesora|ejecutivo|ejecutiva|alguien\s+del\s+equipo|nuestro\s+equipo|
             el\s+equipo)\b[^.!?\n]*\b(confirm|resuelv|resolv|ayud|dir[aá]|inform|contact|escrib|comunic|atend|revis)\w*[^.!?\n]*/xi
  NO_ADVISOR = 'La empresa eligió NO prometer que un asesor confirma lo que no encontraste. Reescribe tu mensaje sin esa ' \
               'promesa: di solo que no tienes ese dato y sigue con la pregunta pendiente.'

  def ensure_no_advisor(messages, text)
    return text unless silent_not_found? && text.match?(ADVISOR)

    @trace.event(:revision, 'prometió un asesor (eligieron no hacerlo)')
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_ADVISOR }
    again = clean(run(messages))
    again = text if again.blank? || unsourced?(again)
    again.gsub(ADVISOR, '').gsub(/\s+([,.])/, '\1').gsub(/\.{2,}/, '.').squeeze(' ').strip.sub(/\A[,.\s]+/, '')
  end

  # «Si busca y no encuentra» = sin prometer asesor, y no es que pidió una persona (ahí sí se habla de asesor).
  def silent_not_found?
    answers = @config.answers
    @mode == :reply && @decision.nil? && @config.function.is_a?(Motor2::Functions::Prospects) &&
      Motor2::Functions::ProspectRules.active(answers)['not_found'] == 'silent' && !qualify_skill&.human_requested?
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
    @mode == :reply && @decision.nil? && Motor2::Skills::QualifyFlow.asking_info?(@last_customer) &&
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
end
