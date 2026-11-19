# frozen_string_literal: true

# Motor 2.0 — la secuencia de preguntas la manda el código (Motor2::Skills::Qualify):
#   - si el mensaje del agente no termina con la pregunta pendiente, se le pide una vez y, si
#     tampoco, se agrega tal cual;
#   - si dice que lo pasa al equipo sin haberlo calificado ni pasado (sin llamar la herramienta),
#     se le pide que lo haga o que no lo prometa.
# Lo incluye Motor2::Runner (usa @mode, @decision, @skills, @trace, #run, #clean y #unsourced?).
module Motor2::QuestionGuard
  ASK_AGAIN = 'Tu mensaje debe terminar con esta pregunta, tal cual: «%<ask>s». Reescríbelo (corto) terminando con ella.'
  PROMISE = /(pas(o|ar|aré|o) (tu|sus|la) (información|info|datos)|te (contact|escrib|llam)(a|e|ar)|un asesor te|alguien del equipo te)/i
  NO_PROMISE = 'Dijiste que lo pasas al equipo, pero no llamaste ninguna herramienta. Si ya cumple lo de «calificado», llama ' \
               'prospecto_calificado (o pasar_a_humano) y despídete; si no, no le digas que lo pasas y sigue con lo que falte.'

  private

  # La secuencia de preguntas la manda el código: si no terminó con la pendiente, se le pide una vez
  # y, si tampoco, se agrega tal cual (no se queda sin preguntar).
  def ensure_question(messages, text)
    ask = pending_question
    return text if ask.blank? || Motor2::Skills::Qualify.asks?(text, ask)

    @trace.event(:revision, 'pregunta pendiente')
    messages << { role: 'assistant', content: text } << { role: 'system', content: format(ASK_AGAIN, ask: ask) }
    again = clean(run(messages))
    return again if again.present? && Motor2::Skills::Qualify.asks?(again, ask) && !unsourced?(again)

    "#{text}\n\n#{ask}"
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
