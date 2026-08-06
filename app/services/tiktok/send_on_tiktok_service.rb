# Envía la respuesta del agente por TikTok.
#
# La API es más estrecha que la de Meta y rechaza el mensaje ENTERO si algo no encaja, así
# que se valida antes de llamar: un rechazo no degrada el mensaje, lo pierde.
class Tiktok::SendOnTiktokService < Base::SendOnChannelService
  SUPPORTED_IMAGE_CONTENT_TYPES = %w[image/jpeg image/png].freeze
  MAX_IMAGE_SIZE = 3.megabytes

  private

  def channel_class
    Channel::Tiktok
  end

  def perform_reply
    validate_message_support!

    message.update!(source_id: send_message)
    Messages::StatusUpdateService.new(message, 'delivered').perform
  rescue StandardError => e
    Rails.logger.error "Failed to send Tiktok message: #{e.message}"
    # El motivo se ve en el propio mensaje: es la única pista que tendrá el agente.
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  def validate_message_support!
    return if message.attachments.empty?

    raise 'TikTok no admite enviar texto y adjunto en el mismo mensaje.' if message.content.present?
    raise 'TikTok no admite enviar varios adjuntos en un mismo mensaje.' unless message.attachments.one?

    validate_attachment_support!(message.attachments.first)
  end

  def validate_attachment_support!(attachment)
    raise 'Esta conversación de TikTok no admite el envío de imágenes.' unless image_send_capable?
    raise 'TikTok solo admite imágenes como adjunto.' unless attachment.image?
    raise 'TikTok solo admite imágenes JPG y PNG.' unless SUPPORTED_IMAGE_CONTENT_TYPES.include?(attachment.file.content_type)
    raise 'Las imágenes de TikTok deben pesar menos de 3 MB.' if attachment.file.byte_size > MAX_IMAGE_SIZE
  end

  # La capacidad se consultó al crear la conversación. Si no se pudo averiguar se deja
  # intentar: mejor que TikTok lo rechace a bloquear un envío que quizá sí valía.
  def image_send_capable?
    message.conversation.additional_attributes.dig('tiktok_capabilities', 'image_send') != false
  end

  def send_message
    if message.attachments.any?
      tiktok_client.send_media_message(tt_conversation_id, message.attachments.first)
    else
      tiktok_client.send_text_message(tt_conversation_id, message.content, referenced_message_id: tt_referenced_message_id)
    end
  end

  # Sin este id no se puede responder: es la conversación del lado de TikTok, guardada al
  # crearla desde el webhook.
  def tt_conversation_id
    message.conversation.additional_attributes['conversation_id']
  end

  def tt_referenced_message_id
    message.content_attributes['in_reply_to_external_id']
  end

  def tiktok_client
    @tiktok_client ||= Tiktok::Client.new(business_id: channel.business_id, access_token: channel.validated_access_token)
  end

  def channel
    @channel ||= message.inbox.channel
  end
end
