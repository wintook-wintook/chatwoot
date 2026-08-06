# El callback de TikTok llega sin sesión de usuario, así que la cuenta viaja de ida y
# vuelta dentro del `state`. Se firma con el App Secret (JWT HS256) en vez de guardarla en
# Redis: así el callback no depende de que la clave siga viva y no se puede falsificar.
module Tiktok::IntegrationHelper
  def generate_tiktok_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate TikTok token: #{e.message}")
    nil
  end

  def verify_tiktok_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token)&.dig('sub')
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('TIKTOK_APP_SECRET', nil)
  end

  # `exp` acota la ventana: el enlace de autorización no sirve indefinidamente si alguien
  # lo copia.
  def token_payload(account_id)
    { sub: account_id, iat: Time.current.to_i, exp: 15.minutes.from_now.to_i }
  end

  def decode_token(token)
    JWT.decode(token, client_secret, true, { algorithm: 'HS256', verify_expiration: true }).first
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Tiktok token: #{e.message}")
    nil
  end
end
