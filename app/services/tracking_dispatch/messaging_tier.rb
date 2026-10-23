# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: tope diario por nivel de Meta
# ================================================================================
# Meta limita a cuántos contactos puede escribirles primero un número de WhatsApp en 24 h
# según su nivel (messaging_limit_tier): 250, 1K, 10K, 100K o ilimitado. Se consulta en la
# Graph API y se guarda en caché 6 horas.
#
# Devuelve nil (sin tope) si el canal no es WhatsApp Cloud, el nivel es ilimitado o la
# consulta falla: en ese caso se comporta como antes de la Fase 2.
# ================================================================================
class TrackingDispatch::MessagingTier
  TIERS = { 'TIER_250' => 250, 'TIER_1K' => 1_000, 'TIER_10K' => 10_000, 'TIER_100K' => 100_000 }.freeze
  CACHE_TTL = 6.hours

  def self.daily_limit(inbox)
    new(inbox).daily_limit
  end

  def initialize(inbox)
    @inbox = inbox
    @channel = inbox&.channel
  end

  def daily_limit
    return unless @channel.is_a?(Channel::Whatsapp) && @channel.provider == 'whatsapp_cloud'

    # skip_nil: si la consulta falla, se vuelve a intentar en la siguiente vuelta.
    tier = Rails.cache.fetch("tracking_dispatch:tier:#{@inbox.id}", expires_in: CACHE_TTL, skip_nil: true) { fetch_tier }
    TIERS[tier]
  end

  private

  def fetch_tier
    config = @channel.provider_config
    base = config['url'].presence || ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    response = HTTParty.get("#{base}/v20.0/#{config['phone_number_id']}",
                            query: { fields: 'messaging_limit_tier' },
                            headers: { 'Authorization' => "Bearer #{config['api_key']}" }, timeout: 10)
    response.success? ? response['messaging_limit_tier'] : nil
  rescue StandardError => e
    Rails.logger.warn "[TrackingDispatch::MessagingTier] inbox #{@inbox.id}: #{e.message}"
    nil
  end
end
