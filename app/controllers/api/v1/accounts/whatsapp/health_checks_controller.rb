# frozen_string_literal: true

# diag/waba F1 — pestaña «Diagnóstico» de una bandeja de WhatsApp Cloud (solo administradores, D1).
#
#   GET  /api/v1/accounts/:account_id/whatsapp/health_checks/:inbox_id            último resultado
#   POST /api/v1/accounts/:account_id/whatsapp/health_checks/:inbox_id/run        corre el diagnóstico
#   POST /api/v1/accounts/:account_id/whatsapp/health_checks/:inbox_id/subscribe  suscribe nuestra app (D4)
class Api::V1::Accounts::Whatsapp::HealthChecksController < Api::V1::Accounts::BaseController
  CACHE_TTL = 7.days

  before_action :fetch_inbox

  def show
    render json: Rails.cache.read(cache_key) || { checked_at: nil, checks: [] }
  end

  def run
    result = Whatsapp::HealthCheckService.new(@inbox).perform
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)
    render json: result
  end

  # Alta con Meta: con la URL de este servidor (como el alta). A mano: sin tocar la URL, porque la
  # WABA puede estar compartida con otro servidor y se le quitarían los mensajes.
  def subscribe
    response = subscribe_request
    return render json: { error: meta_error(response) }, status: :unprocessable_entity unless response.success?

    run
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    authorize @inbox, :update?
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: I18n.t('whatsapp_health.only_cloud') }, status: :unprocessable_entity
  end

  def subscribe_request
    channel = @inbox.channel
    config = channel.provider_config
    client = Whatsapp::FacebookApiClient.new
    return client.subscribe_app(config['business_account_id'], config['api_key']) unless config['source'] == 'embedded_signup'

    callback_url = "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/whatsapp/#{CGI.escape(channel.phone_number)}"
    client.subscribe_webhook(config['business_account_id'], config['api_key'], callback_url, config['webhook_verify_token'])
  end

  def meta_error(response)
    Whatsapp::ErrorTranslator.translate(response.body)[:text]
  end

  def cache_key
    "whatsapp_health:#{@inbox.id}"
  end
end
