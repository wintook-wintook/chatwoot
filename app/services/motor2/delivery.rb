# frozen_string_literal: true

# Motor 2.0 — manda la respuesta del agente a la conversación, con la misma identidad que el
# 1.0 (ContactTrackings::AgentIdentity) y la traza del turno para el probador y el 👍/👎.
# En correo lleva la firma del agente y el pie de baja (ContactTrackings::Signature).
module Motor2::Delivery
  module_function

  def send_reply(tracking, conversation, text, trace: nil, attachments: [])
    return if text.blank? && attachments.empty?

    params = { content: ContactTrackings::Signature.apply(text.to_s, tracking), private: false,
               ai_agent: ContactTrackings::AgentIdentity.for(tracking.tracking_template) }
    params[:attachments] = attachments if attachments.any?
    message = Messages::MessageBuilder.new(sender(tracking.account), conversation, params).perform
    message.content_attributes[:sentiment_auto_reply] = true
    message.content_attributes[:motor2_tracking_id] = tracking.id
    message.content_attributes[:motor2] = trace if trace
    message.save!
    message
  end

  def note(tracking, conversation, text)
    Messages::MessageBuilder.new(sender(tracking.account), conversation,
                                 { message_type: 'outgoing', content: text, private: true }).perform
  rescue StandardError => e
    Rails.logger.error("[Motor2] nota privada: #{e.message}")
  end

  # El mismo «usuario» con el que escribe el 1.0.
  def sender(account)
    account.users.first || AccountUser.where(account_id: account.id).first&.user || User.first
  end
end
