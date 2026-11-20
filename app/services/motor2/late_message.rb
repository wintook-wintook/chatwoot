# frozen_string_literal: true

# Motor 2.0 — mandarle algo al cliente cuando el código lo decide (recordatorio de cita, seguimiento de la
# cotización): dentro de las 24 h de WhatsApp, el texto tal cual; pasadas, con la plantilla aprobada que eligió la
# empresa (sus variables las llena Motor2::TemplateFiller con el texto que se quería mandar). Sin plantilla y fuera
# de la ventana, no se manda (nil).
module Motor2::LateMessage
  module_function

  def deliver(tracking, text, template: nil)
    conversation = tracking.conversation
    return unless conversation
    return Motor2::Delivery.send_reply(tracking, conversation, text) if conversation.can_reply?

    template_send(tracking, conversation, template, text) if template.present?
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
