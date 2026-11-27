# frozen_string_literal: true

# proyecto@arreglar_predefinidas — vectores en lote con la clave de la cuenta, el mismo
# modelo con que se vectorizan las predefinidas (KnowledgeItemSyncJob). nil si falla.
class CannedResponses::Fix::Embedder
  URL = 'https://api.openai.com/v1/embeddings'
  MODEL = 'text-embedding-3-small'

  def initialize(api_key)
    @api_key = api_key
  end

  def call(texts)
    return [] if texts.empty?

    response = http.request(request(texts))
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['data'].sort_by { |d| d['index'] }.pluck('embedding')
  rescue StandardError => e
    Rails.logger.error("[ArreglarPredefinidas] embeddings: #{e.message}")
    nil
  end

  def self.cosine(left, right)
    num = left.zip(right).sum { |x, y| x * y }
    den = Math.sqrt(left.sum { |x| x * x }) * Math.sqrt(right.sum { |y| y * y })
    den.zero? ? 0.0 : num / den
  end

  private

  def http
    Net::HTTP.new(URI(URL).host, 443).tap do |h|
      h.use_ssl = true
      h.read_timeout = 30
    end
  end

  def request(texts)
    Net::HTTP::Post.new(URI(URL)).tap do |r|
      r['Authorization'] = "Bearer #{@api_key}"
      r['Content-Type'] = 'application/json'
      r.body = { model: MODEL, input: texts }.to_json
    end
  end
end
