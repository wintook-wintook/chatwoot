# Encapsula el intercambio OAuth de "Instagram API with Instagram Login".
#
# A diferencia de la ruta legacy (que obtiene el token de la Página de Facebook), aquí el
# usuario autoriza directamente su cuenta de Instagram Business y obtenemos un token
# propio, de larga duración (60 días) y renovable.
#
# OJO: Meta renombra permisos y sube versión de API con frecuencia. Los valores de
# SCOPE y de INSTAGRAM_API_VERSION deben contrastarse con la documentación vigente
# antes de configurar la app en producción. Ver docs/instagram_plan.md §9.4
class Instagram::OauthService
  include HTTParty

  AUTHORIZE_URL = 'https://www.instagram.com/oauth/authorize'.freeze
  TOKEN_URL = 'https://api.instagram.com/oauth/access_token'.freeze
  GRAPH_HOST = 'https://graph.instagram.com'.freeze

  SCOPE = 'instagram_business_basic,instagram_business_manage_messages'.freeze
  PROFILE_FIELDS = 'user_id,username,name,profile_picture_url'.freeze

  class OauthError < StandardError; end

  # URL a la que se manda al administrador para que autorice la cuenta.
  # `state` viaja de ida y vuelta: es la clave con la que recuperamos la cuenta en el callback.
  def authorize_url(state:)
    query = {
      client_id: app_id,
      redirect_uri: redirect_uri,
      response_type: 'code',
      scope: SCOPE,
      state: state
    }.to_query

    "#{AUTHORIZE_URL}?#{query}"
  end

  # code -> token de corta duración (1 hora)
  def exchange_code(code)
    response = HTTParty.post(
      TOKEN_URL,
      body: {
        client_id: app_id,
        client_secret: app_secret,
        grant_type: 'authorization_code',
        redirect_uri: redirect_uri,
        code: code
      }
    )

    parse!(response, 'exchange_code')
  end

  # token de corta duración -> token de larga duración (60 días)
  def exchange_long_lived_token(short_lived_token)
    response = HTTParty.get(
      "#{GRAPH_HOST}/access_token",
      query: {
        grant_type: 'ig_exchange_token',
        client_secret: app_secret,
        access_token: short_lived_token
      }
    )

    parse!(response, 'exchange_long_lived_token')
  end

  # Renueva un token de larga duración. Meta exige que tenga al menos 24 h de vida y que
  # no haya caducado; por eso el job de refresco actúa con margen.
  def refresh_long_lived_token(access_token)
    response = HTTParty.get(
      "#{GRAPH_HOST}/refresh_access_token",
      query: {
        grant_type: 'ig_refresh_token',
        access_token: access_token
      }
    )

    parse!(response, 'refresh_long_lived_token')
  end

  def fetch_profile(access_token)
    response = HTTParty.get(
      "#{GRAPH_HOST}/#{api_version}/me",
      query: {
        fields: PROFILE_FIELDS,
        access_token: access_token
      }
    )

    parse!(response, 'fetch_profile')
  end

  def redirect_uri
    "#{base_url}/instagram/callback"
  end

  private

  def parse!(response, step)
    body = response.parsed_response
    body = {} unless body.is_a?(Hash)

    raise OauthError, "#{step}: #{error_message(body, response)}" unless response.success?

    body.with_indifferent_access
  end

  def error_message(body, response)
    # Meta devuelve el error en `error` (objeto) o en `error_message` (string) según endpoint
    body.dig('error', 'message') || body['error_message'] || body['error'] || "HTTP #{response.code}"
  end

  def app_id
    GlobalConfigService.load('IG_APP_ID', '')
  end

  def app_secret
    GlobalConfigService.load('IG_APP_SECRET', '')
  end

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
