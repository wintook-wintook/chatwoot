# Devuelve siempre un token de acceso utilizable para un Channel::Tiktok.
#
# TikTok da tokens de acceso de ~1 día acompañados de un token de refresco con su propia
# caducidad, así que el token se comprueba y renueva **al usarlo**, no con un job diario:
# con esa vida tan corta, un job nocturno dejaría huecos.
#
# Si el token de refresco también caducó no hay nada que reintentar: se marca el canal
# para reautorizar (banner en el inbox + correo al administrador).
# Ver: docs/tiktok_plan.md §2.2
class Tiktok::TokenService
  pattr_initialize [:channel!]

  # Margen antes del vencimiento: evita entregar un token que caduque en mitad de la
  # llamada que está a punto de hacerse.
  EXPIRY_MARGIN = 5.minutes
  # Si otro proceso está renovando, se le deja terminar en vez de pedir dos tokens.
  REFRESH_LOCK_TTL = 30.seconds

  def access_token
    return current_access_token if token_valid?
    return refresh_access_token if refresh_token_valid?

    channel.prompt_reauthorization! unless channel.reauthorization_required?
    current_access_token
  end

  private

  def current_access_token
    channel.access_token
  end

  def token_valid?
    EXPIRY_MARGIN.from_now < channel.expires_at
  end

  def refresh_token_valid?
    Time.current < channel.refresh_token_expires_at
  end

  def refresh_access_token
    lock_manager = Redis::LockManager.new

    begin
      # Sin el lock, otro proceso ya está renovando: el token actual sigue sirviendo
      # durante el margen, así que se devuelve tal cual en vez de pedir uno nuevo.
      return current_access_token unless lock_manager.lock(lock_key, REFRESH_LOCK_TTL)

      renew_and_store
    ensure
      lock_manager.unlock(lock_key)
    end
  end

  def renew_and_store
    result = Tiktok::AuthClient.renew_short_term_access_token(channel.refresh_token)

    # TikTok rota también el token de refresco: guardar solo el de acceso dejaría el canal
    # sin poder renovarse la próxima vez.
    channel.update!(
      access_token: result[:access_token],
      refresh_token: result[:refresh_token],
      expires_at: result[:expires_at],
      refresh_token_expires_at: result[:refresh_token_expires_at]
    )

    channel.access_token
  end

  def lock_key
    format(::Redis::Alfred::TIKTOK_REFRESH_TOKEN_MUTEX, channel_id: channel.id)
  end
end
