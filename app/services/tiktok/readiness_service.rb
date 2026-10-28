# Comprueba de un vistazo si el canal de TikTok puede funcionar.
#
# Existe porque el fallo típico de TikTok es SILENCIOSO: si el webhook de la aplicación no
# está registrado no llega ni un mensaje, no hay error en ninguna parte y el inbox parece
# perfectamente sano. Lo mismo con el token, que caduca en ~1 día.
#
# Se usa desde `rake tiktok:doctor`.
class Tiktok::ReadinessService
  OK = '✔'.freeze
  KO = '✘'.freeze
  WARN = '⚠'.freeze

  def report
    lines = []
    lines.concat(config_lines)
    lines.concat(webhook_lines)
    lines.concat(accounts_lines)
    lines.concat(channels_lines)
    lines.join("\n")
  end

  private

  def config_lines
    [
      '== Configuración ==',
      status_line(app_id.present?, "TIKTOK_APP_ID#{app_id.present? ? '' : ' sin configurar'}"),
      status_line(app_secret.present?, "TIKTOK_APP_SECRET#{app_secret.present? ? '' : ' sin configurar'}"),
      status_line(frontend_url.present?, "FRONTEND_URL = #{frontend_url.presence || '(vacío)'}"),
      "   URL de callback OAuth : #{Tiktok::AuthClient.redirect_uri}",
      "   URL del webhook       : #{Tiktok::AuthClient.webhook_url}"
    ]
  end

  # El registro del webhook es por APLICACIÓN, no por cuenta: una sola vez para toda la
  # instalación. Se consulta en vivo porque es el dato que nadie recuerda haber tocado.
  def webhook_lines
    ['', '== Webhook registrado en TikTok ==', webhook_status_line]
  end

  def webhook_status_line
    return status_line(false, 'no se puede consultar sin TIKTOK_APP_ID y TIKTOK_APP_SECRET') if app_credentials_missing?

    registered = registered_webhook_urls
    return "  #{KO} TikTok no tiene ninguna URL registrada — ejecuta `rake tiktok:register_webhook`" if registered.blank?
    return status_line(true, "registrado: #{Tiktok::AuthClient.webhook_url}") if registered.include?(Tiktok::AuthClient.webhook_url)

    "  #{KO} registrado en OTRA URL: #{registered.join(', ')} — ejecuta `rake tiktok:register_webhook`"
  rescue StandardError => e
    "  #{KO} error al consultarlo: #{e.class}: #{e.message}"
  end

  def registered_webhook_urls
    data = Tiktok::AuthClient.webhook_callback['data']
    Array.wrap(data.is_a?(Hash) ? data['list'] : data).filter_map { |entry| entry['callback_url'] }
  end

  def accounts_lines
    enabled = Account.select { |account| account.feature_enabled?('channel_tiktok') }
    lines = ['', '== Cuentas con el canal habilitado ==']
    return lines << "  #{WARN} ninguna cuenta tiene la feature `channel_tiktok` activada" if enabled.blank?

    lines + enabled.map { |account| "  #{OK} ##{account.id} #{account.name}" }
  end

  def channels_lines
    lines = ['', '== Canales dados de alta ==']
    return lines << "  #{WARN} todavía no hay ningún canal de TikTok" if channels.blank?

    channels.each { |channel| lines.concat(channel_lines(channel)) }
    lines
  end

  def channel_lines(channel)
    [
      "  · inbox ##{channel.inbox&.id} #{channel.inbox&.name} (business_id #{channel.business_id})",
      "    #{token_status(channel)}",
      "    #{refresh_token_status(channel)}",
      "    #{reauthorization_status(channel)}"
    ]
  end

  # Un access_token caducado no es un problema: TokenService lo renueva al usarlo. Lo que
  # sí rompe el canal es que caduque el de refresco.
  def token_status(channel)
    return "#{WARN} access_token caducado (se renovará solo al primer uso)" if channel.expires_at.past?

    "#{OK} access_token válido hasta #{channel.expires_at}"
  end

  def refresh_token_status(channel)
    return "#{KO} refresh_token CADUCADO — hay que reautorizar el canal a mano" if channel.refresh_token_expires_at.past?

    "#{OK} refresh_token válido hasta #{channel.refresh_token_expires_at}"
  end

  def reauthorization_status(channel)
    return "#{KO} marcado como 'requiere reautorización'" if channel.reauthorization_required?

    "#{OK} autorización al día"
  end

  def channels
    @channels ||= Channel::Tiktok.includes(:inbox).to_a
  end

  def status_line(healthy, text)
    "  #{healthy ? OK : KO} #{text}"
  end

  def app_credentials_missing?
    app_id.blank? || app_secret.blank?
  end

  def app_id
    @app_id ||= GlobalConfigService.load('TIKTOK_APP_ID', nil)
  end

  def app_secret
    @app_secret ||= GlobalConfigService.load('TIKTOK_APP_SECRET', nil)
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', nil)
  end
end
