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

  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end
end
