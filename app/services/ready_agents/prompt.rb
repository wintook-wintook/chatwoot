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
    'collect' => 'juntar sus datos y sus respuestas para que el equipo le dé seguimiento'
  }.freeze
  TONES = { 'cercano' => 'cercano y amable, de tú', 'formal' => 'formal y respetuoso, de usted',
            'directo' => 'directo y práctico, de tú' }.freeze

  def initialize(agent, conversation, answers: {})
    @agent = agent
    @conversation = conversation
    @account = agent.account
    @answers = answers.to_h
  end

  def system
    <<~PROMPT
      Te llamas #{@agent.name} y atiendes por #{channel} a nombre de #{@account.name}. Ahora: #{now}.
      #{off_hours}

      #{ReadyAgents::Catalog.instructions(@agent.kind)}

      LO QUE PIDIÓ LA EMPRESA (si contradice lo anterior, gana esto):
      - Tono: #{TONES[@agent.tone]}.
      - Objetivo cuando califica: #{OBJECTIVES[@agent.objective]}.
      - Preguntas para calificarlo: #{@agent.setting(:questions).presence || 'qué busca y para cuándo'}
      - Está calificado cuando: #{@agent.setting(:qualified_when).presence || 'dijo qué busca y quiere avanzar'}
      - Se descarta cuando: #{@agent.setting(:discard_when).presence || 'no le interesa o no es lo que vendemos'}
      #{"- Indicaciones adicionales: #{@agent.setting(:instructions)}" if @agent.setting(:instructions).present?}

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

  def answers_block
    return '' if @answers.empty?

    "LO QUE YA CONTESTÓ: #{@answers.map { |q, a| "#{q}: #{a}" }.join(' | ')}"
  end
end
