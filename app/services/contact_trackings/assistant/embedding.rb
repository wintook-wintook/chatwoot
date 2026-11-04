# frozen_string_literal: true

# El embedding de una frase, con el mismo modelo que el motor
# (KnowledgeBaseResponseService#generate_embedding_openai): así lo que se prueba en el
# Asistente (probar_fuente, «Probar fuentes») se parece igual que en una conversación.
module ContactTrackings::Assistant::Embedding
  MODEL = 'text-embedding-3-small'

  module_function

  # El vector, o nil sin clave o si la llamada falla.
  def call(texto, api_key)
    return nil if api_key.blank? || texto.to_s.strip.empty?

    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    request = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json')
    request.body = { model: MODEL, input: texto }.to_json
    response = http.request(request)
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body).dig('data', 0, 'embedding') : nil
  rescue StandardError => e
    Rails.logger.warn "[Asistente] embedding falló: #{e.message}"
    nil
  end
end
