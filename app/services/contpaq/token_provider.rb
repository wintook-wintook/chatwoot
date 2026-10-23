# frozen_string_literal: true

# @kbase_contpaq — Token de aplicacion del Agente de Servicio CONTPAQi.
#
# Flujo client_credentials contra Microsoft Entra External ID: no hay usuario final ni
# pantalla de login. El token dura una hora y client_credentials NO emite refresh token,
# asi que al vencer se pide otro.
#
# Se cachea en Redis y no en memoria del proceso: la documentacion del servicio pide
# explicitamente cachear del lado servidor y no pedir un token por llamada, y con varios
# workers de Sidekiq cada uno pediria el suyo.
class Contpaq::TokenProvider
  # Se renueva con dos minutos de sobra. Sin margen, un token que vence entre que se lee
  # de Redis y que llega la peticion produce un 401 evitable.
  EXPIRY_MARGIN = 120

  # Tope defensivo por si el servicio informara una vigencia larga: el token igual se
  # relee, pero no se guarda mas de una hora.
  MAX_TTL = 3600

  def initialize(source)
    @source = source
    @config = source.config.to_h
  end

  # Token vigente, de Redis o recien pedido. nil si no se pudo obtener: el llamador
  # decide (aqui todo es fail-soft, el turno cae al conversacional).
  def token
    cached = Redis::Alfred.get(cache_key)
    return cached if cached.present?

    fetch_and_cache
  end

  # Un 401 con token en mano significa que el que teniamos ya no sirve: se tira para
  # que el reintento pida uno nuevo en vez de repetir el mismo.
  def invalidate!
    Redis::Alfred.delete(cache_key)
  end

  private

  def cache_key
    format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: @source.id)
  end

  def fetch_and_cache
    url = @config['token_url'].to_s
    return nil if url.blank? || @config['client_id'].blank?

    response = post_token(URI.parse(url))
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[CONTPAQi] ❌ Token #{response.code}: #{response.body.to_s.truncate(200)}"
      return nil
    end

    store(JSON.parse(response.body))
  rescue StandardError => e
    Rails.logger.error "[CONTPAQi] ❌ Error pidiendo el token: #{e.message}"
    nil
  end

  def post_token(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(
      'grant_type' => 'client_credentials',
      'client_id' => @config['client_id'].to_s,
      'client_secret' => @config['client_secret'].to_s,
      'scope' => @config['scope'].to_s
    )
    http.request(request)
  end

  def store(data)
    token = data['access_token'].to_s
    return nil if token.blank?

    ttl = data['expires_in'].to_i.clamp(0, MAX_TTL) - EXPIRY_MARGIN
    # Una vigencia menor al margen no se cachea: guardarla con TTL <= 0 la borraria de
    # inmediato y cada llamada terminaria pidiendo token igual.
    Redis::Alfred.set(cache_key, token, ex: ttl) if ttl.positive?
    Rails.logger.info "[CONTPAQi] 🔑 Token obtenido (vigencia #{data['expires_in']}s, cacheado #{ttl}s)"
    token
  end
end
