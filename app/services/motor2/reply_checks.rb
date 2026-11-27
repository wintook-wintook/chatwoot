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
  # Prometer que lo pasan o que lo van a buscar (no «un asesor te confirma el precio»: eso es otra regla).
  PROMISE = /(pas(o|ar|aré)\s+(tu|sus|la)\s+(información|info|datos)|te\s+(contactar|escribir|llamar)[aá]|
             (asesor|alguien\s+del\s+equipo|el\s+equipo)\s+(te\s+)?(contactar|escribir|llamar|buscar)[aá]|
             se\s+pondr[aá]\s+en\s+contacto|te\s+(paso|pasar[eé])\s+con)/xi
  NO_PROMISE = 'Dijiste que lo pasas al equipo, pero no llamaste ninguna herramienta. Si ya cumple lo de «calificado», llama ' \
               'prospecto_calificado (o pasar_a_humano) y despídete; si no, no le digas que lo pasas y sigue con lo que falte.'

  private

  # «No, gracias», «es todo», «gracias»: no se le deja sin respuesta (el modelo a veces contesta [SIN_MENSAJE]).
  FAREWELL = /\A\s*(no,?\s+)?(muchas\s+)?(gracias|es\s+todo|nada\s+m[aá]s|eso\s+es\s+todo|no\s+gracias|ser[ií]a\s+todo)\b/i

  def farewell? = @mode == :reply && @decision.nil? && @last_customer.to_s.match?(FAREWELL)

  def farewell = '¡Con gusto! Aquí estoy si necesitas algo más. 😊'

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
    cleaned = again.gsub(ADVISOR, '').gsub(/\s+([,.])/, '\1').gsub(/\.{2,}/, '.').squeeze(' ').strip.sub(/\A[,.\s]+/, '')
    # Si se fue la frase entera, que al menos diga que no tiene el dato.
    cleaned.match?(NO_DATA) || !again.match?(NO_DATA) ? cleaned : "No tengo ese dato a la mano. #{cleaned}".strip
  end

  NO_DATA = /\bno\s+(tengo|tenemos|encontr|cuento|contamos|manejo|manejamos|dispongo)/i

  # «Si busca y no encuentra» = sin prometer asesor, y no es que pidió una persona (ahí sí se habla de asesor).
  def silent_not_found?
    answers = @config.answers
    @mode == :reply && @decision.nil? && @config.function.is_a?(Motor2::Functions::Prospects) &&
      Motor2::Functions::ProspectRules.active(answers)['not_found'] == 'silent' && !qualify_skill&.human_requested?
  end

  HANDOFF_ASK = 'Pidió hablar con una persona y ya toca pasarlo: llama pasar_a_humano (o canalizar) y despídete (en un momento lo atiende ' \
                'un asesor). No hagas más preguntas.'
  HANDOFF_TEXT = 'Claro, en un momento te atiende un asesor. ¡Gracias por tu paciencia!'

  def ensure_handoff(messages, text)
    return text unless @mode == :reply && @decision.nil? && flow_skill&.must_handoff?

    @trace.event(:revision, 'pidió una persona: se pasa')
    messages << { role: 'assistant', content: text } << { role: 'system', content: HANDOFF_ASK }
    again = clean(run(messages))
    return again.presence || HANDOFF_TEXT if @decision

    @decision = ['handoff', 'Pidió hablar con una persona.']
    HANDOFF_TEXT
  end

  SEARCH_FIRST = 'El cliente preguntó algo y contestaste sin buscar. Si es sobre la empresa o lo que vende, búscalo con ' \
                 'buscar_en_fuentes antes de contestar y, si no sale, no lo afirmes (sigue CÓMO PLATICAS). Si no tiene que ' \
                 'ver con el negocio, no busques: sigue la regla de «fuera de tema». Luego la pregunta pendiente.'
  SEARCH_TOOLS = %w[buscar_en_fuentes buscar_en_catalogo].freeze
  # Ya contestó con otra cosa (el estado de su caso, el archivo que pidió, la liga o la información de la campaña): no
  # hace falta buscar.
  ANSWERED_BY = %w[estado_caso enviar_archivo mandar_liga enviar_informacion reenviar_informacion].freeze

  def ensure_searched(messages, text)
    return text unless unsearched_question?

    @trace.event(:revision, 'contestó sin buscar')
    messages << { role: 'assistant', content: text } << { role: 'system', content: SEARCH_FIRST }
    again = clean(run(messages))
    again.present? && !unsourced?(again) ? again : text
  end

  # Preguntó algo del negocio y no buscó (lo de otro tema sigue la regla de «fuera de tema», sin buscar).
  def unsearched_question?
    @mode == :reply && @decision.nil? && !campaign_facts? && Motor2::Skills::QualifyFlow.asking_info?(@last_customer) && can_search_unused? &&
      Motor2::AnswerCheck.new(account: @account).about_business?(message: @last_customer, business: business_text)
  end

  def can_search_unused?
    find_skill('knowledge')&.searchable? && @trace.tools.none? { |t| ANSWERED_BY.include?(t['name']) && t['ok'] } && @trace.tools.none? do |t|
      SEARCH_TOOLS.include?(t['name'])
    end
  end

  # Campaña con IA con ficha: lo de la campaña se contesta con LA FICHA (lo demás, con fuentes, lo dice su regla).
  def campaign_facts?
    function = @config.function
    function.is_a?(Motor2::Functions::CampaignSeller) && (function.facts.present? || function.content.present?)
  end

  def business_text = @config.function.respond_to?(:business_info) ? @config.function.business_info(:business_what) : @config.objective

  DEFER = 'Eso te lo resuelve un asesor en cuanto te atienda.'

  # «No contesta dudas»: si preguntó algo y el mensaje no dice que un asesor se lo resuelve, se agrega.
  def ensure_defer(_messages, text)
    return text unless deferring? && Motor2::Skills::QualifyFlow.asking_info?(@last_customer) && !text.match?(/asesor|equipo/i)

    @trace.event(:revision, 'no contesta dudas: un asesor se lo resuelve')
    "#{DEFER} #{text}".strip
  end

  def deferring?
    @mode == :reply && @decision.nil? && @config.function.is_a?(Motor2::Functions::Prospects) &&
      !Motor2::Functions::ProspectRules.answers_doubts?(@config.answers)
  end

  # Prometió pasarlo sin llamar la herramienta: se le pide una vez que lo haga bien.
  def ensure_decision(messages, text)
    return text unless undecided_promise?(text)

    @trace.event(:revision, 'prometió pasarlo sin calificarlo')
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_PROMISE }
    again = clean(run(messages))
    again.present? && !unsourced?(again) ? again : text
  end

  # Si pidió una persona y toca terminar primero, «con gusto te paso…» es lo que se espera.
  def undecided_promise?(text)
    @mode == :reply && @decision.nil? && qualify_skill.present? && !qualify_skill.human_requested? && text.match?(PROMISE)
  end
end
