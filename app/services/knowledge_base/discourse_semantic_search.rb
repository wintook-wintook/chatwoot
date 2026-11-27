# frozen_string_literal: true

# ================================================================================
# LA BÚSQUEDA SEMÁNTICA DEL FORO (Discourse AI), FUERA DEL MOTOR
# ================================================================================
# Era el cuerpo de KnowledgeBaseResponseService#discourse_hits. Se sacó aquí (04/11/2026,
# crear_agente_conversando §15 P3) para que la pestaña «Probar fuentes» consulte el foro
# exactamente como el motor, sin copiar la llamada. El motor sigue igual: con 404 (foro
# sin el plugin) cae a la búsqueda normal (DiscourseKeywordSearch); con cualquier error,
# no hay resultados.
# ================================================================================

module KnowledgeBase::DiscourseSemanticSearch
  NOT_AVAILABLE = :not_available

  module_function

  # Los hits de una consulta ({ post_id:, title:, url:, blurb: }), NOT_AVAILABLE si el foro
  # no tiene Discourse AI (404), o [] si falló.
  def hits(query, config)
    url = config['url'].to_s.chomp('/')
    response = request(url, query, config)
    return NOT_AVAILABLE if response.code == '404'

    data = JSON.parse(response.body)
    Rails.logger.info "[KBase] 📚 #{(data['posts'] || []).size} resultado(s) en Discourse semantic-search"
    KnowledgeBase::DiscourseKeywordSearch.to_hits(data, url)
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error en Discourse search: #{e.message}"
    []
  end

  def request(url, query, config)
    uri = URI("#{url}/discourse-ai/embeddings/semantic-search.json")
    uri.query = URI.encode_www_form(q: query)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri)
    request['Api-Key'] = config['api_key'].to_s if config['api_key'].present?
    request['Api-Username'] = config['username'].presence || 'system'
    request['Content-Type'] = 'application/json'
    http.request(request)
  end
end
