# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LOS ARCHIVOS QUE VAN EN UN INTENTO DEL SEGUIMIENTO
# ================================================================================
# Pedido del usuario (10/11/2026): «los archivos adjuntos se envían de diferentes formas…
# en ocasiones se envían en x intento del seguimiento». En la ficha cada archivo dice en
# qué intentos va (TrackingTemplate#file_rules → 'attempts').
#
# El mensaje del intento lo escribe la IA y ahí un {{archivo}} no se resuelve; por eso,
# si el intento salió bien, los archivos van en un mensaje aparte por el flujo normal
# (MessageBuilder → envío del canal): sirve en WhatsApp con la ventana abierta y en los
# demás canales. Con la ventana de WhatsApp cerrada solo puede salir la plantilla (su
# encabezado puede llevar el archivo): ahí no se manda nada.
# ================================================================================

module ContactTrackings::AttemptFiles
  module_function

  # numero: el intento que se acaba de mandar (1, 2, …). Regresa el mensaje o nil.
  def send_for(tracking, numero, sender:)
    template = tracking.tracking_template
    return nil if template.nil?

    nombres = template.files_for_attempt(numero)
    return nil if nombres.empty?

    conversation = tracking.conversation || Conversation.find_by(id: tracking.conversation_id)
    return nil if conversation.nil?

    ContactTrackings::EventFiles.deliver(template, conversation, nombres, sender)
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] 📎 no se mandaron los archivos del intento #{numero}: #{e.message}"
    nil
  end
end
