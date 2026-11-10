# frozen_string_literal: true

# Seguimiento IA — un turno con la ventana de 24 h de WhatsApp cerrada. El modelo ve las
# plantillas que puede usar (todas las aprobadas y usables de la bandeja, o solo la que fijó
# quien delegó), elige una, llena sus variables y la manda con enviar_plantilla. Solo se
# manda una por turno; si ninguna sirve, ninguna_plantilla y el seguimiento se detiene
# avisando por qué. Lo usa AiFollowUps::Runner.
class AiFollowUps::TemplateTurn
  attr_reader :refusal

  def initialize(follow_up, sender:)
    @follow_up = follow_up
    @conversation = follow_up.conversation
    @sender = sender
    @templates = AiFollowUps::Templates.new(@conversation)
    @sent = nil
    @refusal = nil
  end

  def possible?
    candidates.any?
  end

  # Por qué no se puede escribir (canal sin plantillas, plantilla fijada que ya no sirve o ninguna usable).
  def unavailable_reason
    return AiFollowUps::Runner::BLOCKED unless @templates.whatsapp?
    return AiFollowUps::Runner::NO_TEMPLATES if @follow_up.template_name.blank?

    "#{AiFollowUps::Runner::BLOCKED} La plantilla fijada «#{@follow_up.template_name}» ya no está aprobada o no se puede usar."
  end

  def sent?
    @sent.present?
  end

  def candidates
    @candidates ||= if @follow_up.template_name.present?
                      [@templates.find(@follow_up.template_name, @follow_up.template_language)].compact
                    else
                      @templates.available
                    end
  end

  def instructions
    <<~TEXT
      La ventana de 24 h de WhatsApp está cerrada: no se le puede escribir texto libre al cliente, solo una plantilla
      aprobada. Toca #{@follow_up.attempts.zero? ? 'el primer contacto' : "el intento #{@follow_up.attempts + 1} de #{@follow_up.max_attempts}"}.
      Elige la plantilla que mejor sirva al OBJETIVO y mándala con enviar_plantilla, llenando cada variable con datos
      reales (de la conversación, el cliente, el caso o las indicaciones). No inventes datos: si una plantilla pide algo
      que no sabes, elige otra. Prefiere las de categoría UTILITY sobre MARKETING si sirven igual.
      #{repeat_rule}
      Si ninguna sirve para el objetivo, usa ninguna_plantilla con el motivo. Tu texto final no se envía.

      PLANTILLAS DISPONIBLES:
      #{catalog}
    TEXT
  end

  def send_template(args)
    return { error: 'Ya mandaste una plantilla en este turno.' } if sent?

    template = candidate(args['nombre'], args['idioma'])
    return { error: "«#{args['nombre']}» no está entre las plantillas disponibles." } unless template
    return { error: 'Ya la mandaste la vez anterior y no contestó: elige otra distinta.' } if repeated?(template)

    filled = @templates.fill(template[:name], template[:language], args['variables'])
    return filled if filled[:error]

    deliver(filled, args['motivo'])
    { ok: true, enviada: template[:name], texto: filled[:content] }
  end

  def refuse(reason)
    @refusal = "Ninguna plantilla sirve: #{reason.to_s.strip.presence || 'sin motivo'}"
    { ok: true }
  end

  private

  def candidate(name, language)
    candidates.find { |t| t[:name] == name.to_s && (language.blank? || t[:language].to_s.casecmp?(language.to_s)) }
  end

  def deliver(filled, reason)
    message = Messages::MessageBuilder.new(@sender, @conversation,
                                           { content: filled[:content], private: false,
                                             template_params: filled[:template_params], ai_agent: { name: nil } }).perform
    message.content_attributes[:ai_follow_up_id] = @follow_up.id
    message.content_attributes[:sentiment_auto_reply] = true
    message.save!
    @sent = filled[:template][:name]
    @follow_up.add_log(:template, "#{@sent}#{" — #{reason}" if reason.present?}: #{filled[:content]}")
  end

  def catalog
    candidates.map do |t|
      vars = t[:variables].any? ? "variables: #{t[:variables].map { |v| "{{#{v}}}" }.join(', ')}" : 'sin variables'
      "- #{t[:name]} (idioma #{t[:language]}, #{t[:category]}, #{vars}): #{t[:body].squish.truncate(400)}"
    end.join("\n")
  end

  def repeat_rule
    return '' if last_sent.blank?

    failed = " (WhatsApp la rechazó: #{last_message.external_error.presence || 'sin motivo'})" if last_message.failed?
    "La última que mandaste fue «#{last_sent}»#{failed || ' y no contestó'}#{'; elige otra distinta' if candidates.size > 1}."
  end

  def repeated?(template)
    candidates.size > 1 && template[:name] == last_sent
  end

  def last_sent
    last_message&.additional_attributes.to_h.dig('template_params', 'name')
  end

  # El último mensaje de plantilla que mandó este seguimiento.
  def last_message
    return @last_message if defined?(@last_message)

    @last_message = @follow_up.messages.where(private: false).reorder(created_at: :desc).limit(10)
                              .find { |m| m.additional_attributes.to_h.dig('template_params', 'name').present? }
  end
end
