# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LOS ARCHIVOS QUE VAN EN UN INTENTO DEL SEGUIMIENTO
# ================================================================================
# Pedido del usuario (10/11/2026): «los archivos adjuntos se envían de diferentes formas…
# en ocasiones se envían en x intento del seguimiento». En la ficha cada archivo dice en
# qué intentos va (TrackingTemplate#file_rules → 'attempts').
#
# El mensaje del intento lo escribe la IA y ahí un {{archivo}} no se resuelve; por eso,
# en correo van adjuntos al mismo correo del intento (fix/campanas) y, en los demás
# canales, si el intento salió bien, en un mensaje aparte por el flujo normal
# (MessageBuilder → envío del canal): sirve en WhatsApp con la ventana abierta y en los
# demás canales. Con la ventana de WhatsApp cerrada solo puede salir la plantilla (su
# encabezado puede llevar el archivo): ahí no se manda nada.
# ================================================================================

module ContactTrackings::AttemptFiles
  module_function

  # Campaña con Vendedor IA: primero los de la campaña (solo en el primer correo), luego los del vendedor para ese toque.
  def names_for(tracking, numero)
    (campaign_names(tracking, numero) + tracking.tracking_template.files_for_attempt(numero)).uniq
  end

  def campaign_names(tracking, numero)
    # Los de la campaña no van por toque; en correo, los de «cuando muestre interés» van adjuntos al primer correo
    # (el que lleva todo).
    campaign = tracking.tracking_campaign
    return [] unless campaign&.motor2? && first_email?(tracking, numero)

    campaign.offer_files.select { |f| f.rules.to_h['interest'].present? }.map(&:name)
  end

  def first_email?(tracking, numero) = numero.to_i == 1 && tracking.inbox&.email?

  def scope_for(tracking)
    campaign = tracking.tracking_campaign
    return nil unless campaign&.motor2?

    AiAgentAttachment.where(tracking_template_id: tracking.tracking_template_id).or(AiAgentAttachment.of_campaign(campaign))
  end

  # numero: el intento que se acaba de mandar (1, 2, …). Regresa el mensaje o nil.
  def send_for(tracking, numero, sender:)
    template = tracking.tracking_template
    return nil if template.nil?

    nombres = names_for(tracking, numero)
    return nil if nombres.empty?

    conversation = tracking.conversation || Conversation.find_by(id: tracking.conversation_id)
    return nil if conversation.nil?

    ContactTrackings::EventFiles.deliver(template, conversation, nombres, sender, scope: scope_for(tracking))
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] 📎 no se mandaron los archivos del intento #{numero}: #{e.message}"
    nil
  end

  # fix/campanas: en correo los archivos van adjuntos al mismo correo del intento
  # (ContactTrackingJob#send_attempt_with_files). Regresa los signed_id de sus blobs.
  def signed_ids_for(tracking, numero)
    template = tracking.tracking_template
    return [] if template.nil?

    nombres = names_for(tracking, numero)
    nombres.empty? ? [] : ContactTrackings::AgentAttachments.signed_ids(template, nombres, scope: scope_for(tracking))
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] 📎 no se tomaron los archivos del intento #{numero}: #{e.message}"
    []
  end
end
