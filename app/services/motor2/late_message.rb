# frozen_string_literal: true

# Motor 2.0 — mandarle algo al cliente cuando el código lo decide (recordatorio de cita, seguimiento de la
# cotización): dentro de las 24 h de WhatsApp, el texto tal cual; pasadas, con la plantilla aprobada que eligió la
# empresa (sus variables las llena Motor2::TemplateFiller con el texto que se quería mandar). Sin plantilla y fuera
# de la ventana, no se manda (nil).
module Motor2::LateMessage
  # En WhatsApp se deja una hora de margen antes de que cierre la ventana: el mensaje con IA tarda en escribirse y
  # lo que llega pasada la hora 24 Meta lo rechaza.
  MARGIN = 1.hour

  module_function

  def deliver(tracking, text, template: nil)
    conversation = tracking.conversation
    return unless conversation
    return Motor2::Delivery.send_reply(tracking, conversation, text) if window_open?(conversation)

    template_send(tracking, conversation, template, text) if template.present?
  end

  # ¿Se le puede escribir libre? (correo: siempre; WhatsApp: hasta la hora 23 desde su último mensaje)
  def window_open?(conversation)
    return false unless conversation.can_reply?
    return true unless conversation.inbox&.whatsapp?

    last = conversation.last_incoming_message
    last.present? && last.created_at > (24.hours - MARGIN).ago
  end

  def template_send(tracking, conversation, name, text)
    templates = AiFollowUps::Templates.new(conversation)
    template = templates.find(name)
    return unless template

    values = Motor2::TemplateFiller.new(account: tracking.account).call(body: template[:body], variables: template[:variables],
                                                                        facts: { 'mensaje' => text, 'cliente' => tracking.contact&.name })
    filled = templates.fill(template[:name], template[:language], values)
    return if filled[:error]

    Messages::MessageBuilder.new(Motor2::Delivery.sender(tracking.account), conversation,
                                 { content: filled[:content], template_params: filled[:template_params], private: false }).perform
  end
end
