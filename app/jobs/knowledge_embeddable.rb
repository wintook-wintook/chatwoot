# @knowledge_sources — helper compartido para generar embeddings con la key de OpenAI
# de la cuenta (multi-tenant, sin fallback a ENV global). Usado por los jobs de sync
# de Google Docs/Sheets.
module KnowledgeEmbeddable
  extend ActiveSupport::Concern

  def generate_embedding(account, text)
    api_key = openai_api_key(account)
    return unless api_key

    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KnowledgeEmbeddable] Error generating embedding: #{e.message}"
    nil
  end

  # ==============================================================================
  # @knowledge_sources — EMBEDDINGS EN LOTE
  # ==============================================================================
  # Igual que generate_embedding pero con muchos textos por petición. Devuelve un
  # array de vectores EN EL MISMO ORDEN que los textos, con nil en los que fallen.
  #
  # POR QUÉ HACE FALTA:
  #   El de a uno manda una petición HTTP por chunk. Medido el 09/09/2026 contra la
  #   API real y con contenido real: 239 ms por chunk de a uno, contra 8 ms en lotes
  #   llenos — unas 28 veces más rápido. (Con lotes chicos la ventaja baja a 4×,
  #   porque ahí manda el costo fijo de la petición y no el tamaño del lote.)
  #   Con Google Docs nunca se notó, porque un documento son dos o tres chunks; un
  #   sitio WordPress de 1.100 entradas son 2.286 chunks, y eso convierte 17
  #   segundos en 14 minutos de un worker de Sidekiq ocupado.
  #
  # POR QUÉ NO SE CAMBIA EL DE A UNO:
  #   Lo usan los jobs de canned_response y article, donde el volumen es de a un
  #   registro y no molesta. Cambiarlo sería arrastrar riesgo a un camino que hoy
  #   funciona, para no ganar nada.
  #
  # EL ORDEN ES EL CONTRATO:
  #   La API devuelve cada vector con su `index`, y no garantiza el orden del array.
  #   Si se confía en la posición, los chunks quedan con el embedding de otro: la
  #   búsqueda devuelve resultados absurdos y nada falla. Por eso se reordena por
  #   `index` explícitamente.
  # ==============================================================================

  # 100 por petición. Medido: un lote de 100 chunks de 4.000 caracteres son ~81.700
  # tokens, cómodo dentro del límite por petición. Subirlo acerca al techo sin ganar
  # casi nada, porque a 8 ms por chunk el costo ya es la red y no el lote.
  EMBEDDING_BATCH_SIZE = 100
  EMBEDDING_MODEL = 'text-embedding-3-small'.freeze
  EMBEDDING_TIMEOUT = 60

  def generate_embeddings(account, texts)
    api_key = openai_api_key(account)
    return [] if api_key.blank? || texts.blank?

    texts.each_slice(EMBEDDING_BATCH_SIZE).flat_map do |slice|
      embed_slice(api_key, slice) || Array.new(slice.size)
    end
  end

  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end

  private

  # Devuelve los vectores del lote en orden, o nil si el lote entero falló. Que un
  # lote falle no debe tumbar la sincronización: los chunks sin vector se saltean y
  # el resto del sitio queda indexado.
  def embed_slice(api_key, slice)
    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = EMBEDDING_TIMEOUT

    response = http.request(embedding_request(uri, api_key, slice))
    return log_batch_failure("HTTP #{response.code}: #{response.body.to_s[0, 200]}") unless response.is_a?(Net::HTTPSuccess)

    ordered_vectors(JSON.parse(response.body)['data'], slice.size)
  rescue StandardError => e
    log_batch_failure("#{e.class}: #{e.message}")
  end

  def embedding_request(uri, api_key, slice)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: EMBEDDING_MODEL, input: slice }.to_json
    request
  end

  # Se coloca cada vector en la posición que dice su `index`, no en la que vino.
  def ordered_vectors(data, size)
    return nil if data.blank?

    vectors = Array.new(size)
    data.each { |row| vectors[row['index'].to_i] = row['embedding'] }
    vectors
  end

  def log_batch_failure(detail)
    Rails.logger.error "[KnowledgeEmbeddable] lote de embeddings falló — #{detail}"
    nil
  end
end
