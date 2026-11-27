# frozen_string_literal: true

# Motor 2.0 — buscar en un foro (fuente «discourse»). El foro no guarda nada en la plataforma: se
# consulta en vivo, como en el 1.0 (KnowledgeBaseResponseService#search_discourse, que no se toca):
#   1. los temas que corresponden: búsqueda semántica (KnowledgeBase::DiscourseSemanticSearch) y, si el
#      foro no tiene Discourse AI, la normal con 1–3 búsquedas cortas (KnowledgeBase::DiscourseKeywordSearch);
#   2. el texto de cada publicación (GET /posts/:id.json → raw), con pausa entre una y otra (límite del foro).
#
#   Motor2::ForumSearch.new(source, ask: ->(messages) { texto }).call('¿cómo cambio mi contraseña?')
#   → [{ titulo:, informacion:, liga: }]
class Motor2::ForumSearch
  MAX_RESULTS = 3
  MAX_POST_CHARS = 2000
  PAUSE = 1.5

  def initialize(source, ask:)
    @config = source.config.to_h
    @ask = ask
    @url = @config['url'].to_s.chomp('/')
  end

  def call(question)
    hits(question).uniq { |hit| hit[:post_id] }.first(MAX_RESULTS).each_with_index.filter_map do |hit, index|
      sleep(PAUSE) if index.positive?
      content = post(hit[:post_id]).presence || hit[:blurb]
      { titulo: hit[:title].to_s.first(200), informacion: content.to_s.first(MAX_POST_CHARS), liga: hit[:url] }.compact_blank if content.present?
    end
  rescue StandardError => e
    Rails.logger.warn("[Motor2::ForumSearch] #{e.class}: #{e.message}")
    []
  end

  private

  def hits(question)
    found = KnowledgeBase::DiscourseSemanticSearch.hits(question, @config)
    return Array(found) unless found == KnowledgeBase::DiscourseSemanticSearch::NOT_AVAILABLE

    KnowledgeBase::DiscourseKeywordSearch.new(@config, ask: @ask).hits(question)
  end

  def post(post_id)
    return '' if post_id.blank?

    uri = URI("#{@url}/posts/#{post_id}.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 8
    response = http.request(request(uri))
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body)['raw'].to_s.strip : ''
  rescue StandardError => e
    Rails.logger.warn("[Motor2::ForumSearch] post #{post_id}: #{e.message}")
    ''
  end

  def request(uri)
    request = Net::HTTP::Get.new(uri)
    request['Api-Key'] = @config['api_key'].to_s if @config['api_key'].present?
    request['Api-Username'] = @config['username'].presence || 'system'
    request['Content-Type'] = 'application/json'
    request
  end
end
