# Comprueba si la instalación está lista para conectar Instagram por el canal nativo.
#
# Existe porque las piezas están repartidas entre el panel de Super Admin, la app de Meta
# y el flag por cuenta, y cuando algo falla lo hace en silencio: la tarjeta no aparece, o
# el webhook no entrega, sin ningún error visible. Ver docs/instagram_puesta_en_marcha.md
class Instagram::ReadinessService
  Check = Struct.new(:name, :ok, :detail, :fix, keyword_init: true) do
    def status
      ok ? 'OK' : 'FALTA'
    end
  end

  def initialize(account: nil)
    @account = account
  end

  # Re-suscribe al webhook los canales ya conectados. Los que se dieron de alta antes de
  # que el alta suscribiera sola quedaron mudos: token válido, cero entregas.
  def self.subscribe_report(inbox_id: nil)
    channels = inbox_id.present? ? [Inbox.find(inbox_id).channel] : Channel::Instagram.includes(:inbox).to_a
    return '  (no hay canales nativos de Instagram conectados)' if channels.empty?

    channels.map { |channel| subscribe_line(channel) }.join("\n")
  end

  def self.subscribe_line(channel)
    ok = channel.subscribe
    detail = ok ? "suscrito a #{Channel::Instagram::SUBSCRIBED_FIELDS.join(', ')}" : channel.webhook_subscription_error

    format('  [%-5<estado>s] inbox %-6<inbox>s @%-22<user>s %<detalle>s',
           estado: ok ? 'OK' : 'FALLA', inbox: channel.inbox&.id, user: channel.username || '?', detalle: detail)
  end
  private_class_method :subscribe_line

  def checks
    [
      app_id_check,
      app_secret_check,
      verify_token_check,
      api_version_check,
      redirect_uri_check,
      frontend_url_check,
      *shadowed_by_env_checks,
      *account_checks
    ].compact
  end

  # Trampa silenciosa: si .env declara la variable vacía (`INSTAGRAM_APP_ID=`), ENV gana sobre la
  # base de datos y GlobalConfigService devuelve nil. El valor se guarda en Super Admin, se
  # ve guardado, y no surte efecto. Merece un aviso explícito.
  SHADOWABLE_KEYS = %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET INSTAGRAM_VERIFY_TOKEN IG_VERIFY_TOKEN
                       INSTAGRAM_API_VERSION].freeze

  def shadowed_by_env_checks
    SHADOWABLE_KEYS.filter_map do |key|
      next unless ENV.key?(key) && ENV[key].blank?
      next if InstallationConfig.find_by(name: key)&.value.blank?

      Check.new(name: "#{key} anulado por .env", ok: false,
                detail: 'hay valor en Super Admin pero .env lo declara vacío y ENV tiene prioridad',
                fix: "Quita la línea `#{key}=` de .env (o dale valor ahí) y reinicia la aplicación")
    end
  end

  def ready?
    checks.all?(&:ok)
  end

  # Informe legible para la tarea rake
  def report
    ["\n=== Configuración ===", *checks_report, "\n=== Canales conectados ===", *channels_report, '', summary].join("\n")
  end

  # Estado de los canales ya conectados, para vigilar la caducidad del token
  # Memoizado: cada entrada consulta a Meta y el informe recorre la lista más de una vez.
  def channels
    @channels ||= Channel::Instagram.includes(:inbox).map do |channel|
      {
        inbox_id: channel.inbox&.id,
        account_id: channel.account_id,
        username: channel.username,
        instagram_id: channel.instagram_id,
        expires_at: channel.expires_at,
        days_left: channel.expires_at ? ((channel.expires_at - Time.current) / 1.day).round : nil,
        reauthorization_required: channel.reauthorization_required?,
        # Se pregunta a Meta en vivo: la suscripción vive allí, y alguien puede haberla
        # quitado desde el panel de la app sin que aquí cambie nada.
        webhook_subscribed: channel.webhook_subscribed?,
        webhook_error: channel.webhook_subscription_error
      }
    end
  end

  private

  def checks_report
    checks.flat_map do |check|
      line = format('  [%-5<status>s] %-34<name>s %<detail>s', status: check.status, name: check.name, detail: check.detail)
      check.ok ? [line] : [line, format('           ↳ %<fix>s', fix: check.fix)]
    end
  end

  def channels_report
    return ['  (ninguno todavía)'] if channels.empty?

    channels.flat_map { |c| channel_lines(c) }
  end

  # Sin suscripción al webhook el canal no recibe nada, aunque el token esté perfecto:
  # por eso va primero en la línea y con su propia pista de arreglo.
  def channel_lines(channel)
    estado = channel[:reauthorization_required] ? 'REAUTORIZAR' : "caduca en #{channel[:days_left] || '?'} días"
    webhook = channel[:webhook_subscribed] ? 'webhook OK   ' : 'webhook FALTA'
    line = format('  inbox %-6<inbox>s cuenta %-6<account>s @%-22<user>s %<webhook>s %<estado>s',
                  inbox: channel[:inbox_id], account: channel[:account_id], user: channel[:username] || '?',
                  webhook: webhook, estado: estado)

    return [line] if channel[:webhook_subscribed]

    [line,
     format('           ↳ %<detail>s', detail: channel[:webhook_error].presence || 'la app no está suscrita a esta cuenta de Instagram'),
     format('           ↳ Arréglalo con: bundle exec rake instagram:subscribe INBOX_ID=%<inbox>s', inbox: channel[:inbox_id])]
  end

  def summary
    headline = ready? ? '✅ Listo para conectar Instagram.' : '❌ Faltan cosas por configurar (ver arriba).'
    "#{headline}\nGuía completa: docs/instagram_puesta_en_marcha.md"
  end

  def app_id_check
    value = GlobalConfigService.load('INSTAGRAM_APP_ID', '')
    Check.new(name: 'INSTAGRAM_APP_ID', ok: value.present?, detail: value.presence || '(vacío)',
              fix: 'Super Admin → Instagram → Instagram App ID')
  end

  def app_secret_check
    value = GlobalConfigService.load('INSTAGRAM_APP_SECRET', '')
    Check.new(name: 'INSTAGRAM_APP_SECRET', ok: value.present?, detail: value.present? ? '(configurado)' : '(vacío)',
              fix: 'Super Admin → Instagram → Instagram App Secret')
  end

  # El webhook admite cualquiera de los dos nombres: INSTAGRAM_VERIFY_TOKEN (upstream) o
  # IG_VERIFY_TOKEN (el que ya usaba la ruta legacy de esta instalación).
  def verify_token_check
    upstream = GlobalConfigService.load('INSTAGRAM_VERIFY_TOKEN', '')
    legacy = GlobalConfigService.load('IG_VERIFY_TOKEN', '')
    configured = [upstream, legacy].compact_blank

    detail = if configured.empty?
               '(vacío)'
             else
               "(configurado en #{upstream.present? ? 'INSTAGRAM_VERIFY_TOKEN' : 'IG_VERIFY_TOKEN'})"
             end

    Check.new(name: 'Verify token del webhook', ok: configured.any?, detail: detail,
              fix: 'Super Admin → Instagram → Instagram Verify Token, y el mismo valor en el webhook de la app de Meta')
  end

  def api_version_check
    value = GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v25.0')
    Check.new(name: 'INSTAGRAM_API_VERSION', ok: value.present?, detail: value, fix: 'Super Admin → Instagram')
  end

  def redirect_uri_check
    uri = ::Instagram::OauthService.new.redirect_uri
    Check.new(name: 'Redirect URI', ok: uri.start_with?('https://'), detail: uri,
              fix: 'Debe estar dada de alta tal cual en la app de Meta, y ser accesible por HTTPS')
  end

  def frontend_url_check
    url = ENV.fetch('FRONTEND_URL', nil)
    Check.new(name: 'FRONTEND_URL', ok: url.present?, detail: url.presence || '(vacío)',
              fix: 'De aquí sale la redirect URI y las URLs de los adjuntos que Meta descarga')
  end

  def account_checks
    return [] if @account.blank?

    enabled = @account.feature_enabled?('channel_instagram')
    [Check.new(name: "Flag channel_instagram (cuenta #{@account.id})", ok: enabled,
               detail: enabled ? 'activo' : 'inactivo',
               fix: 'Super Admin → Cuentas → editar la cuenta → marcar channel_instagram')]
  end
end
