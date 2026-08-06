# Convierte un evento de mensaje del webhook de TikTok en un Message de Chatwoot.
#
# Atiende los dos sentidos: `im_receive_msg` (entrante) e `im_send_msg`, que llega tanto
# como eco de lo que enviamos desde Chatwoot como cuando alguien responde desde la propia
# app de TikTok. La dirección no se deduce del nombre del evento sino de quién es el
# destinatario, que es lo único fiable.
class Tiktok::MessageService
  include Tiktok::MessagingHelpers

  pattr_initialize [:channel!, :content!, :outgoing_echo]

  def perform
    # Idempotencia: el eco de un mensaje que ya guardamos al enviarlo no debe duplicarlo,
    # y TikTok puede reintentar la entrega del webhook.
    return if outgoing_message? && find_message(tt_conversation_id, tt_message_id).present?

    create_message
  end

  private

  def contact_inbox
    @contact_inbox ||= create_contact_inbox(
      channel, tt_conversation_id,
      incoming_message? ? from : to,
      incoming_message? ? from_id : to_id
    )
  end

  def conversation
    @conversation ||= find_conversation(channel, tt_conversation_id) ||
                      create_conversation(channel, contact_inbox, tt_conversation_id)
  end

  def create_message
    message = conversation.messages.build(
      content: message_content,
      account_id: channel.inbox.account_id,
      inbox_id: channel.inbox.id,
      message_type: incoming_message? ? :incoming : :outgoing,
      content_attributes: message_content_attributes,
      source_id: tt_message_id,
      # Se respeta la hora de TikTok: si el webhook llega con retraso, el mensaje debe
      # quedar en su sitio dentro de la conversación.
      created_at: tt_message_time,
      updated_at: tt_message_time
    )

    message.sender = contact_inbox.contact if incoming_message?
    # Si TikTok ya lo entregó, no tiene sentido dejarlo en "enviando".
    message.status = :delivered if outgoing_message?

    build_attachments(message)
    message.save!
  end

  # Solo el texto tiene contenido; imagen y post compartido viajan como adjunto.
  def message_content
    tt_text_body if text_message?
  end

  def build_attachments(message)
    build_image_attachment(message) if image_message?
    build_share_post_attachment(message) if share_post_message?
  end

  def build_image_attachment(message)
    file = fetch_attachment(channel, tt_conversation_id, tt_message_id, tt_image_media_id)

    message.attachments.new(
      account_id: message.account_id,
      file_type: :image,
      file: { io: file, filename: file.original_filename, content_type: file.content_type }
    )
  end

  # Un vídeo de TikTok compartido en el chat: no hay fichero que descargar, solo la URL
  # del contenido incrustado.
  def build_share_post_attachment(message)
    message.attachments.new(account_id: message.account_id, file_type: :embed, external_url: tt_share_post_embed_url)
  end

  def supported_message?
    text_message? || image_message? || share_post_message?
  end

  def message_content_attributes
    attributes = {}
    attributes[:in_reply_to_external_id] = tt_referenced_message_id if tt_referenced_message_id
    # Lo que no sabemos representar (pegatinas, por ahora) se guarda igual, marcado: es
    # preferible una conversación con un hueco visible a una conversación con un salto.
    attributes[:is_unsupported] = true unless supported_message?
    # Salió de la cuenta pero no desde Chatwoot: el front lo distingue del enviado por un
    # agente.
    attributes[:external_echo] = true if outgoing_echo
    attributes
  end

  def text_message?
    tt_message_type == 'text'
  end

  def image_message?
    tt_message_type == 'image'
  end

  def share_post_message?
    tt_message_type == 'share_post'
  end

  def tt_text_body
    content.dig(:text, :body)
  end

  def tt_image_media_id
    content.dig(:image, :media_id)
  end

  def tt_share_post_embed_url
    content.dig(:share_post, :embed_url)
  end

  def tt_referenced_message_id
    content.dig(:referenced_message_info, :referenced_message_id)
  end

  def tt_message_type
    content[:type]
  end

  def tt_message_id
    content[:message_id]
  end

  def tt_conversation_id
    content[:conversation_id]
  end

  # TikTok manda el timestamp en milisegundos.
  def tt_message_time
    Time.zone.at(content[:timestamp].to_i / 1000).utc
  end

  def from
    content[:from]
  end

  def from_id
    content.dig(:from_user, :id)
  end

  def to
    content[:to]
  end

  def to_id
    content.dig(:to_user, :id)
  end

  # Si el destinatario es la cuenta de empresa, el mensaje entra.
  def incoming_message?
    channel.business_id.to_s == to_id.to_s
  end

  def outgoing_message?
    !incoming_message?
  end
end
