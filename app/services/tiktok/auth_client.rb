# Habla con la parte de autenticación de la TikTok Business API: obtener el token a partir
# del código de autorización, renovarlo, y consultar/fijar la URL del webhook.
#
# Ojo con el registro del webhook: en TikTok es **por aplicación y una sola vez**, no por
# cuenta como en Meta. Si no se hace, no llega ni un mensaje y no hay ningún error visible.
# Ver: docs/tiktok_plan.md §6.1
class Tiktok::AuthClient
  # El callback exige que se concedan TODOS: una autorización parcial deja el canal
  # inutilizable, así que se comprueban al volver del OAuth.
  REQUIRED_SCOPES = %w[
    user.info.basic user.info.username user.info.stats user.info.profile
    user.account.type user.insights
    message.list.read message.list.send message.list.manage
  ].freeze

  class TiktokApiError < StandardError; end

  class << self
    def authorize_url(state: nil)
      client = ::OAuth2::Client.new(
        client_id,
        client_secret,
        {
          site: 'https://www.tiktok.com',
          authorize_url: '/v2/auth/authorize',
          auth_scheme: :basic_auth
        }
      )

      client.authorize_url(
        response_type: 'code',
        # TikTok llama `client_key` a lo que OAuth2 manda como `client_id`; hay que
        # enviarlo explícitamente además del que pone la gema.
        client_key: client_id,
        redirect_uri: redirect_uri,
        scope: REQUIRED_SCOPES.join(','),
        state: state
      )
    end

    # código de autorización -> token de acceso (~1 día) + token de refresco
    # @see https://business-api.tiktok.com/portal/docs?id=1832184159540418
    def obtain_short_term_access_token(auth_code)
      json = post_json(
        'tt_user/oauth2/token/',
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'authorization_code',
        auth_code: auth_code,
        redirect_uri: redirect_uri
      )

      # `open_id` es el identificador de la cuenta de empresa: es con el que llegan los
      # webhooks, así que es lo que guardamos como business_id.
      token_payload(json).merge(
        business_id: json['data']['open_id'],
        scope: json['data']['scope']
      )
    end

    def renew_short_term_access_token(refresh_token)
      json = post_json(
        'tt_user/oauth2/refresh_token/',
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      )

      token_payload(json)
    end

    # URL de webhook que TikTok tiene registrada hoy para esta app.
    def webhook_callback
      response = HTTParty.get(
        "#{api_base_url}/business/webhook/list/",
        query: { app_id: client_id, secret: client_secret, event_type: 'DIRECT_MESSAGE' },
        headers: { 'Accept' => 'application/json' }
      )

      process_json_response(response, 'Failed to fetch TikTok webhook callback')
    end

    # Fija la URL del webhook de esta instalación. Es idempotente.
    def update_webhook_callback
      post_json(
        'business/webhook/update/',
        app_id: client_id,
        secret: client_secret,
        event_type: 'DIRECT_MESSAGE',
        callback_url: webhook_url
      )
    end

    def redirect_uri
      "#{base_url}/tiktok/callback"
    end

    def webhook_url
      "#{base_url}/webhooks/tiktok"
    end

    private

    def token_payload(json)
      data = json['data']

      {
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        expires_at: Time.current + data['expires_in'].seconds,
        refresh_token_expires_at: Time.current + data['refresh_token_expires_in'].seconds
      }.with_indifferent_access
    end

    def post_json(path, **body)
      response = HTTParty.post(
        "#{api_base_url}/#{path}",
        body: body.to_json,
        headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
      )

      process_json_response(response, "Failed to call TikTok #{path}")
    end

    # TikTok responde HTTP 200 con `code != 0` cuando algo falla, así que no basta con
    # mirar el estado de la respuesta.
    def process_json_response(response, error_prefix)
      unless response.success?
        Rails.logger.error "#{error_prefix}. Status: #{response.code}, Body: #{response.body}"
        raise TiktokApiError, "#{response.code}: #{response.body}"
      end

      json = JSON.parse(response.body)
      raise TiktokApiError, "#{json['code']}: #{json['message']}" if json['code'] != 0

      json
    end

    def client_id
      GlobalConfigService.load('TIKTOK_APP_ID', nil)
    end

    def client_secret
      GlobalConfigService.load('TIKTOK_APP_SECRET', nil)
    end

    def base_url
      ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    end

    def api_base_url
      "https://business-api.tiktok.com/open_api/#{GlobalConfigService.load('TIKTOK_API_VERSION', 'v1.3')}"
    end
  end
end
