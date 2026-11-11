# frozen_string_literal: true

# Agentes listos — lo que el agente sabe antes de cada turno, en capas: el puesto (nuestro,
# global: ReadyAgents::Catalog), lo que la empresa contestó al activarlo y el cliente.
# Si lo de la empresa contradice al puesto, gana lo de la empresa.
class ReadyAgents::Prompt
  HISTORY = 30
  MESSAGE_CHARS = 1500
  OBJECTIVES = {
    'handoff' => 'pasárselo a una persona del equipo para que lo atienda',
    'opportunity' => 'crearle la oportunidad de venta y pasársela al equipo',
    'collect' => 'juntar sus datos y sus respuestas para que el equipo le dé seguimiento',
    'appointment' => 'agendarle una cita'
  }.freeze
  TONES = { 'cercano' => 'cercano y amable, de tú', 'formal' => 'formal y respetuoso, de usted',
            'directo' => 'directo y práctico, de tú' }.freeze

  def initialize(agent, conversation, answers: {})
    @agent = agent
    @conversation = conversation
    @account = agent.account
    @answers = answers.to_h
  end

  # El puesto (igual para todas las empresas) primero y lo del momento (hora, cliente) al final:
  # OpenAI cobra con descuento el inicio idéntico de una llamada reciente (prompt caching).
  def system
    <<~PROMPT
      #{ReadyAgents::Catalog.instructions(@agent.kind)}

      #{business_block}
      #{hours_block}
      #{company_block}

      #{questions_block}
      #{objections_block}
      #{contact_block}
      #{appointment_block}
      Te llamas #{@agent.name} y atiendes por #{channel} a nombre de #{@account.name}. Ahora: #{now}.
      #{off_hours}
      CLIENTE: #{contact_line}
      #{answers_block}
      Si no hay nada que decir en este turno, responde exactamente #{ReadyAgents::Runner::NO_MESSAGE}.
    PROMPT
  end

  # La conversación como mensajes reales (cliente = user, nosotros = assistant), sin notas privadas.
  def history
    @conversation.messages.where(private: false, message_type: %i[incoming outgoing])
                 .reorder(created_at: :desc).limit(HISTORY).to_a.reverse.filter_map do |m|
      text = ContactTrackings::AttachmentText.message_text(m).presence
      next if text.blank?

      { role: m.incoming? ? 'user' : 'assistant', content: text.first(MESSAGE_CHARS) }
    end
  end

  private

  def now
    Time.current.in_time_zone(zone).strftime('%Y-%m-%d %H:%M (%A)')
  end

  def zone
    ActiveSupport::TimeZone[@conversation.inbox&.timezone.to_s] || Time.zone
  end

  def channel
    @conversation.inbox&.channel_type.to_s.delete_prefix('Channel::').presence || 'chat'
  end

  def off_hours
    return '' unless @conversation.inbox.respond_to?(:out_of_office?) && @conversation.inbox.out_of_office?

    'AHORA ESTÁ FUERA DEL HORARIO DE ATENCIÓN: atiéndelo igual, pero si toca pasarlo a una persona dile que le ' \
      'escriben en cuanto abran.'
  end

  def contact_line
    contact = @conversation.contact
    return 'sin datos' unless contact

    [contact.name, contact.email, contact.phone_number, contact.additional_attributes.to_h['company_name']].compact_blank.join(' · ')
  end

  BUSINESS = { business_what: 'Qué vende', business_who: 'A quién le vende (cliente ideal)',
               business_coverage: 'Dónde da servicio', business_why: 'Por qué elegirnos',
               business_practical: 'Precios desde, formas de pago y tiempos' }.freeze

  # Lo que la empresa contó de su negocio: para explicar y para descartar a quien está fuera.
  def business_block
    lines = BUSINESS.filter_map { |key, label| "- #{label}: #{@agent.setting(key)}" if @agent.setting(key).present? }
    lines << '- Lo que vendemos y sus precios están en el Catálogo: búscalo con buscar_en_catalogo.' if @agent.setting(:business_use_catalog)
    return '' if lines.empty?

    <<~TEXT
      EL NEGOCIO (úsalo para explicar; si el prospecto está fuera de la zona o de lo que vendemos, es para descartar):
      #{lines.join("\n")}
    TEXT
  end

  def company_block
    <<~TEXT
      LO QUE PIDIÓ LA EMPRESA (si contradice lo anterior, gana esto):
      - Tono: #{TONES[@agent.tone]}.
      - Objetivo cuando califica: #{OBJECTIVES[@agent.objective]}.
      - Está calificado cuando: #{@agent.setting(:qualified_when).presence || 'dijo qué busca y quiere avanzar'}
      - Se descarta cuando: #{@agent.setting(:discard_when).presence || 'no le interesa o no es lo que vendemos'}
      #{"- Indicaciones adicionales: #{@agent.setting(:instructions)}" if @agent.setting(:instructions).present?}
    TEXT
  end

  WEEKDAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

  # El horario de atención de la bandeja (si lo tiene prendido): para «¿abren el domingo?».
  def hours_block
    inbox = @conversation.inbox
    return '' unless inbox.respond_to?(:working_hours_enabled?) && inbox.working_hours_enabled?

    days = inbox.working_hours.sort_by { |w| (w.day_of_week + 6) % 7 }.map { |w| "#{WEEKDAYS[w.day_of_week]} #{hours_text(w)}" }
    "HORARIO DE ATENCIÓN (#{zone.tzinfo.name}): #{days.join('; ')}.\n"
  end

  def hours_text(hours)
    return 'cerrado' if hours.closed_all_day?
    return 'todo el día' if hours.open_all_day?

    format('%<oh>02d:%<om>02d a %<ch>02d:%<cm>02d', oh: hours.open_hour.to_i, om: hours.open_minutes.to_i,
                                                    ch: hours.close_hour.to_i, cm: hours.close_minutes.to_i)
  end

  def questions_block
    questions = ReadyAgents::Qualification.questions(@agent)
    own = @agent.setting(:questions).presence
    lines = questions.map { |q| "- #{q[:label]}: «#{q[:ask]}»" }
    lines << "- Preguntas propias de la empresa: #{own}" if own
    lines << '- Qué busca y para cuándo' if lines.empty?
    <<~TEXT
      PREGUNTAS PARA CALIFICARLO (en este orden, una por mensaje, con tus palabras y sin repetir lo que ya dijo).
      Al guardar_respuesta usa como «pregunta» el nombre de antes de los dos puntos (p. ej. «Presupuesto»):
      #{lines.join("\n")}

      TEMPERATURA: al calificarlo (o pasarlo a una persona) di qué tan listo está:
      - caliente: lo necesita pronto (este mes) y tiene presupuesto o decide la compra.
      - tibio: le interesa, pero es para más adelante o falta saber el presupuesto o quién decide.
      - frio: solo está explorando o comparando, sin fecha.
    TEXT
  end

  def objections_block
    list = ReadyAgents::Qualification.objections(@agent)
    return '' if list.empty?

    lines = list.map { |o| "- «#{o[:objection]}» → #{o[:answer]}" }
    <<~TEXT
      OBJECIONES FRECUENTES (contesta con esta idea, con tus palabras; no ofrezcas descuentos que no estén aquí):
      #{lines.join("\n")}
    TEXT
  end

  def contact_block
    fields = ReadyAgents::Qualification.required_contact(@agent).map { |f| ReadyAgents::Qualification::CONTACT_FIELDS[f] }
    return '' if fields.empty?

    "DATOS OBLIGATORIOS: cuando ya califique, si falta su #{fields.to_sentence(last_word_connector: ' y ', two_words_connector: ' y ')}, " \
      'pídelo con naturalidad ANTES de prospecto_calificado y antes de despedirte; cuando lo dé, guárdalo con ' \
      "actualizar_contacto y entonces califícalo.\n"
  end

  # Con el objetivo «agendarle una cita» y calendarios conectados.
  def appointment_block
    return '' unless ReadyAgents::Appointments.available?(@agent)

    kind = @agent.setting(:appointment_kind).presence || 'llamada'
    place = @agent.setting(:appointment_location).presence
    <<~TEXT.strip
      CITAS (#{kind}, #{@agent.setting(:appointment_minutes).presence || 30} min#{", #{place}" if place}):
      - Cuando califique, ofrécele 2 o 3 horarios de ver_horarios (di día y hora como vienen en «texto»). Si pide
        otro día u hora, ver_horarios con «desde». No ofrezcas horarios que no salieron de ver_horarios.
      - Cuando elija uno, agendar_cita con ese «inicio» y confirma el día, la hora y con quién. No hace falta
        llamar prospecto_calificado: agendar la cita ya lo califica.
      - Si después quiere moverla o cancelarla: mover_cita o cancelar_cita.
    TEXT
  end

  def answers_block
    return '' if @answers.empty?

    "LO QUE YA CONTESTÓ: #{@answers.map { |q, a| "#{q}: #{a}" }.join(' | ')}"
  end
end
