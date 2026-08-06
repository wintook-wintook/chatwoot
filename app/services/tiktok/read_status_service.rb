# Marca como leídos los mensajes que la otra parte ya vio.
#
# TikTok no acusa mensaje a mensaje: manda un único evento `im_mark_read_msg` con la marca
# de tiempo hasta la que se leyó todo el hilo. De ahí que se actualice por lote.
class Tiktok::ReadStatusService
  include Tiktok::MessagingHelpers

  pattr_initialize [:channel!, :content!]

  def perform
    # El evento también llega cuando somos NOSOTROS quienes leemos desde la app de TikTok.
    # Ese caso no dice nada del cliente y marcaría como leído lo que nadie leyó.
    return if outbound_event?
    return if conversation.blank?

    ::Conversations::UpdateMessageStatusJob.perform_later(conversation.id, last_read_timestamp)
  end

  private

  def conversation
    @conversation ||= find_conversation(channel, tt_conversation_id)
  end

  def tt_conversation_id
    content[:conversation_id]
  end

  # TikTok manda el timestamp en milisegundos.
  def last_read_timestamp
    Time.zone.at(content.dig(:read, :last_read_timestamp).to_i / 1000).utc
  end

  def outbound_event?
    channel.business_id.to_s == content.dig(:from_user, :id).to_s
  end
end
