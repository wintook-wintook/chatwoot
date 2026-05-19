# proyecto@waba_chatwoot
# Whatsapp::FacebookApiClient
#
# Cliente HTTP centralizado para todas las llamadas a la Graph API de Meta.
# Encapsula la autenticación y las operaciones necesarias para el flujo
# de WhatsApp Embedded Signup:
#
#   exchange_code_for_token  — Intercambia el código OAuth de corta duración
#                              por un access token de larga duración.
#   validate_token_access    — Verifica que el token tenga acceso al WABA
#                              indicado mediante el endpoint debug_token.
#   fetch_phone_info         — Obtiene los números de teléfono asociados al
#                              WABA y devuelve datos del número elegido.
#   register_phone           — Registra el número en la plataforma de WhatsApp
#                              Cloud si aún no está verificado.
#   subscribe_webhook        — Suscribe el webhook de Chatwoot al WABA para
#                              recibir mensajes entrantes.
#
# Variables de config requeridas (Super Admin → whatsapp_embedded):
#   WHATSAPP_EMBEDDED_FACEBOOK_APP_ID
#   WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET
#   WHATSAPP_EMBEDDED_FACEBOOK_API_VERSION  (default: v22.0)
#
class Whatsapp::FacebookApiClient
  BASE_URI = 'https://graph.facebook.com'.freeze

  def initialize
    @app_id = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_APP_ID', '')
    @app_secret = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET', '')
    @api_version = GlobalConfigService.load('WHATSAPP_EMBEDDED_FACEBOOK_API_VERSION', 'v22.0')
  end

  def exchange_code_for_token(code)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/oauth/access_token",
      query: {
        client_id: @app_id,
        client_secret: @app_secret,
        code: code
      }
    )
    raise "Token exchange failed: #{response.body}" unless response.success?

    data = response.parsed_response
    raise 'No access token in response' if data['access_token'].blank?

    data['access_token']
  end

  def fetch_phone_info(waba_id, access_token, phone_number_id = nil)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/phone_numbers",
      query: { access_token: access_token }
    )
    raise "Failed to fetch phone numbers: #{response.body}" unless response.success?

    phones = response.parsed_response['data'] || []
    raise 'No phone numbers found for WABA' if phones.empty?

    phone = phone_number_id.present? ? phones.find { |p| p['id'].to_s == phone_number_id.to_s } : phones.first
    raise "Phone number ID #{phone_number_id} not found in WABA" if phone.nil?

    {
      phone_number_id: phone['id'],
      phone_number: "+#{phone['display_phone_number']&.gsub(/\D/, '')}",
      verified: phone['code_verification_status'] == 'VERIFIED',
      business_name: phone['verified_name']
    }
  end

  def validate_token_access(access_token, waba_id)
    app_token = "#{@app_id}|#{@app_secret}"
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/debug_token",
      query: {
        input_token: access_token,
        access_token: app_token
      }
    )
    raise "Token validation failed: #{response.body}" unless response.success?

    data = response.parsed_response['data'] || {}
    granular_scopes = data['granular_scopes'] || []
    waba_scope = granular_scopes.find { |s| s['scope'] == 'whatsapp_business_management' }
    raise 'No WABA scope found in token' if waba_scope.nil?
    raise 'Token does not have access to WABA' unless waba_scope['target_ids']&.include?(waba_id.to_s)
  end

  def register_phone(phone_number_id, access_token)
    pin = rand(100_000..999_999).to_s
    HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/register",
      headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
      body: { messaging_product: 'whatsapp', pin: pin }.to_json
    )
  end

  def subscribe_webhook(waba_id, access_token, callback_url, verify_token)
    HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
      body: {
        override_callback_uri: callback_url,
        verify_token: verify_token
      }.to_json
    )
  end
end
