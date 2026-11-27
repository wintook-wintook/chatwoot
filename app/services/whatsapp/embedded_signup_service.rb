# proyecto@waba_chatwoot
# Whatsapp::EmbeddedSignupService
#
# Orquesta el flujo completo de WhatsApp Embedded Signup.
# Es invocado por AuthorizationsController al recibir los datos del popup
# de Meta (código OAuth + datos del negocio).
#
# Flujo que ejecuta perform():
#   1. Valida que lleguen code, business_id y waba_id.
#   2. Intercambia el code por un access_token (server-side, seguro).
#   3. Verifica que el token tenga permisos sobre el WABA indicado.
#   4. Obtiene la información del número de teléfono desde Meta.
#   5. Crea el inbox en Chatwoot (o actualiza uno existente si se pasa inbox_id).
#   6. Registra el webhook en Meta para recibir mensajes entrantes.
#
# El canal creado queda marcado con source: 'embedded_signup' en provider_config
# para distinguirlo de canales creados manualmente.
#
class Whatsapp::EmbeddedSignupService
  def initialize(account:, params:)
    @account = account
    @code = params[:code]
    @business_id = params[:business_id]
    @waba_id = params[:waba_id]
    @phone_number_id = params[:phone_number_id]
    @inbox_id = params[:inbox_id]
    @client = Whatsapp::FacebookApiClient.new
  end

  def perform
    validate_parameters!
    @access_token = @client.exchange_code_for_token(@code)
    @client.validate_token_access(@access_token, @waba_id)
    @phone_info = @client.fetch_phone_info(@waba_id, @access_token, @phone_number_id)
    channel = create_or_find_channel
    @webhook_result = setup_webhooks(channel)
    channel
  end

  def webhook_result
    @webhook_result || { success: false, url: nil, token: nil }
  end

  private

  def validate_parameters!
    raise ArgumentError, 'Missing code' if @code.blank?
    raise ArgumentError, 'Missing business_id' if @business_id.blank?
    raise ArgumentError, 'Missing waba_id' if @waba_id.blank?
  end

  def create_or_find_channel
    if @inbox_id.present?
      reconnect_channel(@account.inboxes.find(@inbox_id).channel)
    else
      create_channel
    end
  end

  # diag/waba F3 — «Reconectar con Meta»: misma bandeja, mismo número (H1), token nuevo y sin la
  # marca de reconexión (H2). Una bandeja dada de alta a mano conserva su origen: así no se le
  # manda la URL de este servidor a Meta (la WABA puede estar compartida con otro servidor).
  def reconnect_channel(channel)
    raise ArgumentError, I18n.t('whatsapp_health.reconnect.other_number', number: @phone_info[:phone_number]) unless same_number?(channel)

    @reconnect_manual = channel.provider_config['source'] != 'embedded_signup'
    channel.update!(
      provider_config: channel.provider_config.merge(
        'api_key' => @access_token,
        'phone_number_id' => @phone_info[:phone_number_id],
        'business_account_id' => @waba_id
      )
    )
    channel.reauthorized!
    channel
  end

  def same_number?(channel)
    channel.phone_number.to_s.gsub(/\D/, '') == @phone_info[:phone_number].to_s.gsub(/\D/, '')
  end

  def create_channel
    existing = Channel::Whatsapp.find_by(phone_number: @phone_info[:phone_number])
    raise 'Channel already exists for this phone number' if existing.present?

    channel = Channel::Whatsapp.new(
      account: @account,
      phone_number: @phone_info[:phone_number],
      provider: 'whatsapp_cloud',
      provider_config: {
        'api_key' => @access_token,
        'phone_number_id' => @phone_info[:phone_number_id],
        'business_account_id' => @waba_id,
        'source' => 'embedded_signup'
      }
    )

    inbox_name = "#{@phone_info[:business_name]} WhatsApp".strip
    inbox_name = @phone_info[:phone_number] if inbox_name == 'WhatsApp'

    inbox = @account.inboxes.build(name: inbox_name, channel: channel)
    inbox.save!
    channel
  end

  def setup_webhooks(channel)
    frontend_url = ENV.fetch('FRONTEND_URL', '')
    phone_number_encoded = CGI.escape(channel.phone_number)
    callback_url = "#{frontend_url}/webhooks/whatsapp/#{phone_number_encoded}"
    verify_token = channel.provider_config['webhook_verify_token']

    # diag/waba F3 — al reconectar NO se registra el número: registrarlo pone un PIN nuevo de
    # verificación en dos pasos (code_verification_status EXPIRED es normal en Cloud).
    @client.register_phone(@phone_info[:phone_number_id], @access_token) unless @phone_info[:verified] || @inbox_id.present?

    response = if @reconnect_manual
                 @client.subscribe_app(@waba_id, @access_token)
               else
                 @client.subscribe_webhook(@waba_id, @access_token, callback_url, verify_token)
               end
    if response.success?
      { success: true, url: callback_url, token: verify_token }
    else
      Rails.logger.error "[WHATSAPP] Webhook setup failed (#{response.code}): #{response.body}"
      { success: false, url: callback_url, token: verify_token, error: response.body }
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup error: #{e.message}"
    { success: false, url: callback_url, token: verify_token, error: e.message }
  end
end
