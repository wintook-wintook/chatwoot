# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — ARCHIVOS QUE VAN CUANDO PASA ALGO EN LA CONVERSACIÓN
# ================================================================================
# Pedido del usuario (10/11/2026): además de «cuando lo pidan», «con la bienvenida» y
# «en el intento N», un archivo puede ir:
#   :booking  al confirmar una cita (mapa, indicaciones)
#   :ticket   al levantar un ticket de cierto tipo (formato, pasos a seguir)
# Va en un mensaje aparte después del aviso del motor (como AttemptFiles).
# («Con la ruta X» no pasa por aquí: la ficha escribe {{archivo}} en el alcance de esa
# ruta y el modelo lo manda al contestar.)
# ================================================================================

module ContactTrackings::EventFiles
  module_function

  def send_for(tracking, evento, conversation:, sender:, case_type: nil)
    template = tracking&.tracking_template
    return nil if template.nil? || conversation.nil?

    nombres = evento == :booking ? template.files_for_booking : template.files_for_ticket(case_type)
    deliver(template, conversation, nombres, sender)
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] 📎 no se mandaron los archivos (#{evento}): #{e.message}"
    nil
  end

  def deliver(template, conversation, nombres, sender)
    return nil if nombres.empty?

    signed = ContactTrackings::AgentAttachments.signed_ids(template, nombres)
    return nil if signed.empty?

    Messages::MessageBuilder.new(sender, conversation,
                                 { content: '', private: false, attachments: signed,
                                   ai_agent: ContactTrackings::AgentIdentity.for(template) }).perform
  end
end
