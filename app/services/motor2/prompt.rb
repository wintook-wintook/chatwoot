# frozen_string_literal: true

# Motor 2.0 — lo que el agente lee en cada turno, en capas (plan §11.4):
#   1. lo nuestro, igual para todos (reglas y cómo usar cada habilidad) y, si el agente es de una
#      función (§11.14), su puesto con lo que la empresa contestó en el asistente;
#   2. la empresa: «Cómo habla tu empresa», datos del negocio, lo que nunca debe hacer y sus
#      instrucciones en texto libre (si contradicen la capa 1, ganan, salvo las reglas del código);
#   3. el agente: quién es, su objetivo y contexto;
#   4. lo del momento: hora, cliente, nota IA y lo que el código recuerda (al final, para que
#      OpenAI reuse el inicio idéntico: prompt caching).
class Motor2::Prompt
  HISTORY = 30
  MESSAGE_CHARS = 1500
  TONES = { 'tu' => 'de tú (nunca de vos)', 'usted' => 'de usted' }.freeze

  TURNS = {
    reply: 'El cliente acaba de escribir (último mensaje). Contesta y sigue con tu objetivo.',
    attempt: 'El cliente no ha contestado. Toca el intento %<n>s de %<total>s para retomar el contacto. Escribe un ' \
             'mensaje corto y natural según tu objetivo, sin repetir lo que ya le dijiste y sin mencionar intentos ' \
             'ni seguimientos automáticos.'
  }.freeze

  def initialize(turn, skills)
    @turn = turn
    @config = turn.config
    @skills = skills
    @account = @config.account
  end

  def system
    [ours, function, company, agent, moment].compact_blank.join("\n\n")
  end

  def turn_message(mode, attempt: nil)
    format(TURNS.fetch(mode), n: attempt&.first, total: attempt&.last)
  end

  # La conversación como mensajes reales (cliente = user, nosotros = assistant), sin notas privadas.
  # upto: hasta ese mensaje, incluido (para corregir una respuesta de una conversación real).
  def self.history(conversation, upto: nil)
    return [] unless conversation.respond_to?(:messages) && conversation.messages

    scope = conversation.messages.where(private: false, message_type: %i[incoming outgoing])
    scope = scope.where(id: ..upto.id) if upto
    scope.reorder(created_at: :desc).limit(HISTORY).to_a.reverse.filter_map do |m|
      text = Motor2::MessageText.call(m).presence # con lo que dicen sus notas de voz e imágenes
      next if text.blank?

      { role: m.incoming? ? 'user' : 'assistant', content: text.first(MESSAGE_CHARS) }
    end
  end

  private

  def ours
    <<~TEXT.strip
      Atiendes a clientes por chat a nombre de una empresa. Reglas:
      - Escribe como una persona del equipo por chat: corto (2 o 3 renglones salvo que pidan detalle), claro y amable.
      - Una sola pregunta por mensaje. No repitas lo que ya dijiste ni vuelvas a saludar si ya saludaste.
      - Si te preguntan si eres una persona, no mientas: eres el asistente virtual de la empresa.
      - Ligas: solo las que aparezcan tal cual en tus fuentes o instrucciones; cópialas exactas.
      - Si en este turno no hay nada que decir, responde exactamente #{Motor2::Runner::NO_MESSAGE}.
      #{@skills.map(&:instructions).compact_blank.join("\n")}
    TEXT
  end

  def function = @config.function&.prompt(@turn.conversation)

  def company
    parts = [voice_block, AgentBase::BusinessData.block(@account, skip: own_business).presence]
    parts << "DATOS DE ESTE AGENTE:\n#{@config.business.map { |r| "- #{r['label']}: #{r['value']}" }.join("\n")}" if @config.business.any?
    parts << "NUNCA:\n#{@config.never}" if @config.never.present?
    parts << "INSTRUCCIONES DE LA EMPRESA (si contradicen lo anterior, gana esto):\n#{@config.instructions}" if @config.instructions.present?
    parts.compact.join("\n\n")
  end

  # Agentes listos: la de la empresa con lo de este agente, y manda; los demás, la general como siempre.
  def voice_block
    return AgentBase::CompanyVoice.block(@account).presence unless @config.function

    values = @config.voice
    note_voice(values)
    AgentBase::CompanyVoice.block(@account, values, strong: true).presence
  end

  # Para el chat de prueba: qué tomó («Cómo habla tu empresa», y qué cambió este agente).
  def note_voice(values)
    used = values.compact_blank.keys.map { |k| AgentBase::CompanyVoice::FIELDS[k] }
    return if used.empty?

    own = @config.own_voice_fields.map { |k| AgentBase::CompanyVoice::FIELDS[k] }
    @turn.trace.event(:voz, "Cómo habla tu empresa: #{used.join(', ')}#{" (de este agente: #{own.join(', ')})" if own.any?}")
  end

  # Lo que el agente de una función ya trae en su «Tu negocio» no se repite de los datos de la empresa.
  def own_business = @config.function.respond_to?(:business_values) ? @config.function.business_values : []

  def agent
    who = @config.display_name ? "Te llamas #{@config.display_name}" : 'No tienes nombre propio'
    <<~TEXT.strip
      #{who} y atiendes a nombre de #{@account.name}. Habla #{TONES[@config.tone]}.
      TU OBJETIVO: #{@config.objective}
      #{"CONTEXTO: #{@config.context}" if @config.context.present?}
    TEXT
  end

  def moment
    conversation = @turn.conversation
    lines = ["Ahora: #{Time.current.in_time_zone(@config.zone).strftime('%Y-%m-%d %H:%M (%A)')}. Canal: #{channel}."]
    lines << "CLIENTE: #{contact_line(conversation&.contact)}"
    lines << Motor2::InboxHours.block(conversation.try(:inbox) || @config.inbox, @config.zone) if @config.function
    lines << AgentBase::ContactNote.block(conversation&.contact)
    lines.concat(@skills.map(&:memory))
    lines.compact_blank.join("\n")
  end

  def channel
    @config.inbox&.channel_type.to_s.delete_prefix('Channel::').presence || 'chat'
  end

  def contact_line(contact)
    return 'sin datos' unless contact

    [contact.name, contact.email, contact.phone_number, contact.additional_attributes.to_h['company_name']].compact_blank.join(' · ')
  end
end
