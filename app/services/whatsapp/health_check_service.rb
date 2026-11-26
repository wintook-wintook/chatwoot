# frozen_string_literal: true

# diag/waba F1 — diagnóstico de una bandeja de WhatsApp Cloud: por qué no recibe o no envía.
#
#   Whatsapp::HealthCheckService.new(inbox).perform
#   → { checked_at:, checks: [{ key:, group:, status:, title:, detail:, action: }] }
#
#   group  receive | send | system
#   status ok | warn | fail | unknown   (unknown = no se pudo consultar; nunca truena todo)
#   action subscribe | reconnect | update_token | open_meta | nil
#
# Solo CONSULTA (GET a Meta y lecturas locales). Lo que arregla vive en otros endpoints.
# Revisiones del plan docs/waba_diagnostico_plan.md: R0 app del sistema, R1 token, R2 webhook,
# R3 último entrante, R4 número, R5 límite, R6 cuenta, R7 envíos fallidos, R8 marca, R9 cola.
class Whatsapp::HealthCheckService
  GRAPH = 'https://graph.facebook.com'
  TIMEOUT = 8
  STALE_INCOMING = 2.days
  TOKEN_EXPIRES_SOON = 7.days
  FAILED_WINDOW = 7.days
  QUEUE_LATENCY_WARN = 300
  NUMBER_FIELDS = 'status,quality_rating,name_status,verified_name,messaging_limit_tier'

  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
    config = @channel.provider_config || {}
    @token = config['api_key']
    @waba_id = config['business_account_id']
    @phone_id = config['phone_number_id']
    @version = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_API_VERSION', 'v22.0')
    @app_id = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_APP_ID', '')
    @app_secret = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET', '')
    @checks = []
  end

  def perform
    %i[check_app check_token check_webhook check_last_incoming check_number check_waba
       check_failed_messages check_reauthorization check_queue].each { |check| safely(check) }
    { checked_at: Time.current, checks: @checks }
  end

  private

  # ---------- R0 · la app de Meta del sistema (App ID | App Secret) ----------
  def check_app
    code, body = graph_get('oauth/access_token', client_id: @app_id, client_secret: @app_secret, grant_type: 'client_credentials')
    @app_token = body['access_token'] if code == 200
    add(:app, :system, @app_token ? :ok : :fail)
  end

  # ---------- R1 · token de la bandeja ----------
  def check_token
    code, body = graph_get('me', access_token: @token)
    return add(:token, :receive, :fail, action: :reconnect) if token_error?(code, body)
    return add(:token, :receive, :unknown) unless code == 200

    @token_ok = true
    return add(:token, :receive, :ok, detail_key: :no_app) unless @app_token

    token_details
  end

  def token_details
    code, body = graph_get('debug_token', input_token: @token, access_token: @app_token)
    return add(:token, :receive, :ok, detail_key: :no_app) unless code == 200

    data = body['data'] || {}
    expires = data['expires_at'].to_i
    missing = %w[whatsapp_business_messaging whatsapp_business_management] - Array(data['scopes'])
    return add(:token, :receive, :warn, action: :reconnect, detail_key: :scopes, scopes: missing.join(', ')) if missing.any?
    return add(:token, :receive, :ok, detail_key: :permanent) if expires.zero?

    status = Time.zone.at(expires) < TOKEN_EXPIRES_SOON.from_now ? :warn : :ok
    add(:token, :receive, status, action: (:reconnect if status == :warn), detail_key: :expires,
                                  date: I18n.l(Time.zone.at(expires).to_date))
  end

  # ---------- R2 · ¿Meta nos manda los mensajes? ----------
  def check_webhook
    return add(:webhook, :receive, :unknown) unless @token_ok

    code, body = graph_get("#{@waba_id}/subscribed_apps", access_token: @token)
    return add(:webhook, :receive, :unknown) unless code == 200

    ours = Array(body['data']).find { |a| a.dig('whatsapp_business_api_data', 'id').to_s == @app_id.to_s }
    return add(:webhook, :receive, :fail, action: :subscribe, detail_key: :not_subscribed) unless ours

    compare_callback(ours['override_callback_uri'].presence || app_callback_url)
  end

  def app_callback_url
    return nil unless @app_token

    code, body = graph_get("#{@app_id}/subscriptions", access_token: @app_token)
    return nil unless code == 200

    Array(body['data']).find { |s| s['object'] == 'whatsapp_business_account' }&.dig('callback_url')
  end

  def compare_callback(url)
    return add(:webhook, :receive, :warn, detail_key: :unverified) if url.blank?

    host = host_of(url)
    return add(:webhook, :receive, :ok) if host == host_of(ENV.fetch('FRONTEND_URL', ''))

    add(:webhook, :receive, :fail, detail_key: :other_server, host: host)
  end

  # ---------- R3 · último mensaje recibido ----------
  def check_last_incoming
    last = @inbox.messages.incoming.maximum(:created_at)
    return add(:last_incoming, :receive, :warn, variant: :never) unless last

    add(:last_incoming, :receive, last < STALE_INCOMING.ago ? :warn : :ok, ago: ago_text(last))
  end

  def ago_text(time)
    minutes = ((Time.current - time) / 60).round
    return I18n.t('whatsapp_health.ago.minutes', count: minutes) if minutes < 60
    return I18n.t('whatsapp_health.ago.hours', count: minutes / 60) if minutes < 48 * 60

    I18n.t('whatsapp_health.ago.days', count: minutes / (60 * 24))
  end

  # ---------- R4 / R5 · número ----------
  def check_number
    return add(:number, :send, :unknown) unless @token_ok

    code, body = graph_get(@phone_id, access_token: @token, fields: NUMBER_FIELDS)
    return add(:number, :send, :unknown) unless code == 200

    add_number(body)
    add_name(body)
    tier = body['messaging_limit_tier']
    tier.present? ? add(:limit, :send, :ok, tier: tier_text(tier)) : add(:limit, :send, :unknown)
  end

  def add_number(body)
    quality = body['quality_rating'].to_s.upcase
    status = number_status(body['status'], quality)
    add(:number, :send, status, action: (:open_meta unless status == :ok), state: body['status'],
                                quality: I18n.t("whatsapp_health.quality.#{quality.downcase}", default: quality.presence || '—'))
  end

  def number_status(state, quality)
    return :fail if !state.to_s.casecmp('CONNECTED').zero? || quality == 'RED'

    quality == 'YELLOW' ? :warn : :ok
  end

  def add_name(body)
    declined = %w[DECLINED REJECTED].include?(body['name_status'].to_s.upcase)
    add(:display_name, :send, declined ? :warn : :ok, action: (:open_meta if declined), name: body['verified_name'].to_s)
  end

  def tier_text(tier)
    I18n.t("whatsapp_health.tiers.#{tier.to_s.downcase}", default: tier.to_s)
  end

  # ---------- R6 · cuenta de WhatsApp Business ----------
  def check_waba
    return add(:account, :send, :unknown) unless @token_ok

    code, body = graph_get(@waba_id, access_token: @token, fields: 'account_review_status')
    return add(:account, :send, :unknown) unless code == 200

    status = { 'APPROVED' => :ok, 'PENDING' => :warn }.fetch(body['account_review_status'].to_s.upcase, :fail)
    add(:account, :send, status, action: (:open_meta unless status == :ok))
  end

  # ---------- R7 · envíos fallidos (7 días), traducidos ----------
  def check_failed_messages
    sent = @inbox.messages.outgoing.where(created_at: FAILED_WINDOW.ago..)
    failed = failed_errors(sent)
    return add(:failed, :send, :ok) if failed.empty?

    groups = failed.map { |raw| Whatsapp::ErrorTranslator.translate(raw)[:text] }.tally.sort_by { |_, n| -n }
    status = failed.size >= 3 && failed.size == sent.count ? :fail : :warn
    add(:failed, :send, status, count: failed.size, lines: groups.map { |text, n| "#{n} · #{text}" })
  end

  # content_attributes va como texto JSON dentro de la columna json (doble codificado): se lee
  # con el modelo, no con ->> en SQL.
  def failed_errors(sent)
    sent.where(status: :failed).select(:id, :content_attributes).map(&:external_error)
  end

  # ---------- R8 · marca «requiere reconexión» ----------
  def check_reauthorization
    required = @channel.reauthorization_required?
    add(:reauthorization, :system, required ? :fail : :ok, action: (:reconnect if required))
  end

  # ---------- R9 · colas de WhatsApp: enviar (SendReplyJob) y recibir (WhatsappEventsJob) ----------
  def check_queue
    queues = [SendReplyJob.queue_name, Webhooks::WhatsappEventsJob.queue_name].map(&:to_s).uniq
    served = Sidekiq::ProcessSet.new.flat_map { |process| process['queues'] }
    idle = queues - served
    return add(:queue, :system, :fail, queues: idle.join(', ')) if idle.any?

    latency = queues.map { |name| Sidekiq::Queue.new(name).latency }.max.to_f
    add(:queue, :system, latency > QUEUE_LATENCY_WARN ? :warn : :ok, minutes: (latency / 60).round)
  end

  # ---------- utilidades ----------
  # opts: action, detail_key, lines, variant (título distinto al del estado, p. ej. «nunca ha
  # recibido» sigue siendo warn) y el resto son variables de los textos.
  def add(key, group, status, **opts)
    base = "whatsapp_health.checks.#{key}"
    action, detail_key, lines, variant = opts.extract!(:action, :detail_key, :lines, :variant).values_at(:action, :detail_key, :lines, :variant)
    @checks << {
      key: key.to_s, group: group.to_s, status: status.to_s, action: action&.to_s,
      title: I18n.t("#{base}.#{variant || status}", **opts),
      detail: detail_key ? I18n.t("#{base}.details.#{detail_key}", **opts) : nil,
      lines: lines
    }
  end

  # Una revisión que truena no tumba las demás: sale «no se pudo revisar».
  def safely(check)
    send(check)
  rescue StandardError => e
    Rails.logger.warn "[WhatsappHealth] inbox #{@inbox.id} #{check}: #{e.class} #{e.message}"
    key = check.to_s.delete_prefix('check_')
    key = 'failed' if key == 'failed_messages'
    @checks << { key: key, group: 'system', status: 'unknown', action: nil,
                 title: I18n.t('whatsapp_health.unknown', check: key), detail: nil, lines: nil }
  end

  def graph_get(path, query)
    response = HTTParty.get("#{GRAPH}/#{@version}/#{path}", query: query, timeout: TIMEOUT)
    body = response.parsed_response
    [response.code, body.is_a?(Hash) ? body : {}]
  rescue StandardError => e
    Rails.logger.warn "[WhatsappHealth] GET #{path.split('/').last}: #{e.message}"
    [nil, {}]
  end

  def token_error?(code, body)
    code == 401 || body.dig('error', 'code').to_i == 190
  end

  def host_of(url)
    URI.parse(url.to_s).host.to_s.downcase
  rescue URI::InvalidURIError
    ''
  end
end
