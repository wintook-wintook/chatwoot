# frozen_string_literal: true

# @tickets_cases F7 — Alta, renovación y cierre del canal de push (plan §12.6).
#
# Un canal por INTEGRACIÓN, nunca uno por reunión. Se abre de forma **perezosa**:
# la primera vez que esa integración espeja una reunión, así no se abren canales
# para agentes que nunca usan el módulo.
#
# El canal caduca (Google fija `expiration`), por eso `RenewCalendarChannelsJob`
# renueva a diario lo que vence en menos de 48 h.
class Cases::Meetings::PushChannelService
  TTL = 7.days
  RENEW_WINDOW = 48.hours

  def initialize(integration)
    @integration = integration
  end

  # Abre el canal si hace falta. Idempotente: si ya hay uno vigente, no hace nada.
  def ensure_channel!
    return false if @integration.blank? || callback_url.blank?
    return false if active_channel?

    open_channel!
  end

  # Cierra el canal en Google y limpia las columnas. Se llama al desconectar la
  # integración: si no, Google sigue mandando pings a un endpoint que ya no tiene
  # tokens para atenderlos (§12.7.6).
  def stop_channel!
    return false if @integration.push_channel_id.blank?

    service.stop_channel(channel_id: @integration.push_channel_id,
                         resource_id: @integration.push_resource_id)
    clear_columns!
    true
  rescue StandardError => e
    Rails.logger.warn("[GestorTickets] cerrar canal de push #{@integration.id}: #{e.message}")
    clear_columns!
    false
  end

  # Renueva: abre un canal nuevo y cierra el viejo (Google no extiende canales).
  def renew!
    stop_channel!
    open_channel!
  end

  private

  def active_channel?
    @integration.push_channel_id.present? &&
      @integration.push_expires_at.present? &&
      @integration.push_expires_at > RENEW_WINDOW.from_now
  end

  def open_channel!
    channel_id = SecureRandom.uuid
    token = SecureRandom.hex(24) # secreto que autentica el ping
    response = service.watch_events(channel_id: channel_id, callback_url: callback_url, token: token, ttl: TTL)

    @integration.update_columns( # rubocop:disable Rails/SkipsModelValidations
      push_channel_id: channel_id,
      push_resource_id: response['resourceId'],
      push_channel_token: token,
      push_expires_at: expiration_from(response),
      # Cursor incremental: sin él, el primer aviso no sabría desde dónde leer.
      sync_token: @integration.sync_token.presence || service.initial_sync_token
    )
    true
  rescue StandardError => e
    # Que falle el push NUNCA rompe el espejo: la reconciliación perezosa sigue
    # siendo la red de seguridad (§12.5).
    Rails.logger.error("[GestorTickets] abrir canal de push #{@integration.id}: #{e.message}")
    false
  end

  def expiration_from(response)
    ms = response['expiration'].to_i
    ms.positive? ? Time.zone.at(ms / 1000) : TTL.from_now
  end

  def clear_columns!
    @integration.update_columns( # rubocop:disable Rails/SkipsModelValidations
      push_channel_id: nil, push_resource_id: nil,
      push_channel_token: nil, push_expires_at: nil
    )
  end

  def service
    @service ||= GoogleCalendarService.new(@integration)
  end

  # La URL pública del callback. Sin dominio verificado en Google Cloud (§12.2),
  # `events.watch` la rechaza — por eso el push es aditivo y su fallo no rompe nada.
  def callback_url
    base = ENV.fetch('FRONTEND_URL', nil).presence || GlobalConfigService.load('FRONTEND_URL', nil)
    return nil if base.blank?

    "#{base.chomp('/')}/google_calendar/notifications"
  end
end
