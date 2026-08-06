# Piezas compartidas entre los servicios que atienden el webhook de TikTok.
#
# ⚠️ Decisión que conviene tener presente: el `source_id` del contact_inbox es el
# **id de la conversación de TikTok**, no el del usuario. La API de mensajería gira sobre
# `conversation_id` y no expone un identificador estable de persona con el que agrupar.
# Consecuencia: si el mismo usuario abriera dos hilos, saldrían como dos contactos.
# Ver: docs/tiktok_plan.md §1
module Tiktok::MessagingHelpers
  private

  def create_contact_inbox(channel, tt_conversation_id, from, from_id)
    ::ContactInboxWithContactBuilder.new(
      source_id: tt_conversation_id,
      inbox: channel.inbox,
      contact_attributes: {
        name: from,
        additional_attributes: contact_additional_attributes(from, from_id)
      }
    ).perform
  end

  def contact_additional_attributes(from, from_id)
    {
      social_profiles: { tiktok: from },
      # El id de usuario sí llega en el evento: se guarda aunque no se use para agrupar,
      # porque es el dato que haría falta si algún día se quiere unificar por persona.
      social_tiktok_user_id: from_id,
      social_tiktok_user_name: from
    }
  end

  def find_conversation(channel, tt_conversation_id)
    contact_inbox = channel.inbox.contact_inboxes.find_by(source_id: tt_conversation_id)
    return if contact_inbox.blank?

    last_open_conversation(channel, contact_inbox) || contact_inbox.conversations.order(created_at: :desc).first
  end

  def last_open_conversation(channel, contact_inbox)
    return contact_inbox.conversations.order(created_at: :desc).first if channel.inbox.lock_to_single_conversation

    contact_inbox.conversations.where.not(status: :resolved).order(created_at: :desc).first
  end

  def create_conversation(channel, contact_inbox, tt_conversation_id)
    ::Conversation.create!(
      account_id: channel.inbox.account_id,
      inbox_id: channel.inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: conversation_additional_attributes(channel, tt_conversation_id)
    )
  end

  # `conversation_id` se guarda aquí porque es lo que hay que mandarle a TikTok al
  # responder: sin él no se puede contestar a la conversación.
  def conversation_additional_attributes(channel, tt_conversation_id)
    attributes = { conversation_id: tt_conversation_id }
    capabilities = tiktok_conversation_capabilities(channel, tt_conversation_id)
    attributes[:tiktok_capabilities] = capabilities if capabilities.present?
    attributes
  end

  # TikTok decide por conversación si admite imágenes. Se consulta al crearla y se cachea:
  # preguntarlo en cada envío sería una llamada de más, y no poder preguntarlo no debe
  # impedir crear la conversación.
  def tiktok_conversation_capabilities(channel, tt_conversation_id)
    { image_send: tiktok_client(channel).image_send_capable?(tt_conversation_id), updated_at: Time.current.iso8601 }
  rescue StandardError => e
    Rails.logger.error(
      "[TikTok] no se pudieron leer las capacidades de la conversación #{tt_conversation_id} " \
      "(business_id=#{channel.business_id}): #{e.class}: #{e.message}"
    )
    {}
  end

  # El `source_id` de un mensaje es único dentro de TikTok, pero se comprueba también la
  # conversación para no confundir dos hilos.
  def find_message(tt_conversation_id, tt_message_id)
    message = Message.find_by(source_id: tt_message_id)
    return if message.blank?
    return if message.conversation&.additional_attributes&.dig('conversation_id') != tt_conversation_id

    message
  end

  def fetch_attachment(channel, tt_conversation_id, tt_message_id, tt_image_media_id)
    url = tiktok_client(channel).file_download_url(tt_conversation_id, tt_message_id, tt_image_media_id)
    # La URL de descarga exige la cabecera `x-user` con el token del canal.
    Down.download(url, headers: { 'x-user' => channel.validated_access_token })
  end

  def tiktok_client(channel)
    Tiktok::Client.new(business_id: channel.business_id, access_token: channel.validated_access_token)
  end
end
