# Reparte los eventos del webhook de TikTok.
#
# El lock es por CONVERSACIÓN, no por usuario: en TikTok la unidad de la API de mensajería
# es el `conversation_id`, y es también el `source_id` del contact_inbox.
# @see https://business-api.tiktok.com/portal/docs?id=1832190670631937
class Webhooks::TiktokEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 8

  SUPPORTED_EVENTS = %w[im_send_msg im_receive_msg im_mark_read_msg].freeze
  LOCK_TIMEOUT = 10.seconds

  def perform(event)
    @event = event.with_indifferent_access

    return if channel_inactive?
    return if event_name.blank?

    key = format(::Redis::Alfred::TIKTOK_MESSAGE_MUTEX, business_id: business_id, conversation_id: conversation_id)
    with_lock(key, LOCK_TIMEOUT) do
      send(event_name)
    end
  end

  private

  # Una cuenta suspendida no debe seguir creando conversaciones, y el canal pudo borrarse
  # entre que TikTok entregó el evento y el job se ejecuta.
  def channel_inactive?
    return true if channel.blank?

    !channel.account.active?
  end

  def channel
    @channel ||= Channel::Tiktok.find_by(business_id: business_id)
  end

  def event_name
    @event_name ||= SUPPORTED_EVENTS.find { |name| name == @event[:event] }
  end

  def business_id
    @business_id ||= @event[:user_openid]
  end

  # El contenido del evento viaja como JSON dentro de una cadena, no como objeto.
  def content
    @content ||= JSON.parse(@event[:content]).deep_symbolize_keys
  rescue JSON::ParserError, TypeError
    {}
  end

  def conversation_id
    @conversation_id ||= content[:conversation_id]
  end

  # Mensaje que sale de la cuenta: o es el eco de algo que enviamos nosotros, o alguien
  # respondió desde la propia app de TikTok.
  def im_send_msg
    ::Tiktok::MessageService.new(channel: channel, content: content, outgoing_echo: true).perform
  end

  # Mensaje entrante. OJO: TikTok solo lo entrega para usuarios FUERA del Espacio
  # Económico Europeo, Suiza y Reino Unido. No es un fallo nuestro, es su política.
  def im_receive_msg
    ::Tiktok::MessageService.new(channel: channel, content: content).perform
  end

  def im_mark_read_msg
    ::Tiktok::ReadStatusService.new(channel: channel, content: content).perform
  end
end
