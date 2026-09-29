# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — BÚSQUEDA NORMAL DEL FORO, CUANDO NO HAY DISCOURSE AI
# ================================================================================
# @buscar_foro usa la búsqueda semántica del plugin Discourse AI
# (/discourse-ai/embeddings/semantic-search.json). Un foro sin el plugin activo contesta
# 404 y el agente se quedaba sin conocimiento: el 28/09/2026, Foro_Sentidos_Creativos
# (agente ADAM) devolvía 0 resultados a todo y cada mensaje terminaba en «Tu caso fue
# registrado».
#
# Entonces se usa la búsqueda normal (/search.json). Esa exige TODAS las palabras: con la
# frase del cliente («Quiero rediseñar la página web de mi restaurante…») da 0; con
# «rediseñar página web» da 7. La IA saca 1 a 3 búsquedas cortas del mensaje y se juntan.
# ================================================================================

class KnowledgeBase::DiscourseKeywordSearch
  MAX_TERMS = 3
  PER_TERM = 4
  STOPWORDS = %w[
    a al algo como con cual cuando de del el ella en es esta este esto hay la las le lo los me mi mis muy
    nada no nos para pero por que qué se sin su sus te tu un una uno unos y ya yo quiero quisiera tengo
    tenemos nuestro nuestra hola buenas buenos dias días tardes noches favor gracias usted ustedes
  ].freeze

  # Los posts y temas de una respuesta de Discourse (semántica o normal: mismo formato).
  def self.to_hits(data, url)
    topics = (data['topics'] || []).index_by { |t| t['id'] }
    (data['posts'] || []).filter_map do |post|
      topic = topics[post['topic_id']]
      next unless topic

      { post_id: post['id'], title: topic['title'].to_s.strip, url: "#{url}/t/#{topic['slug']}/#{topic['id']}",
        blurb: post['blurb'].to_s.strip }
    end
  end

  # ask: recibe los mensajes para la IA y devuelve su texto (o nil).
  def initialize(config, ask:)
    @url = config['url'].to_s.chomp('/')
    @api_key = config['api_key'].to_s
    @username = config['username'].presence || 'system'
    @ask = ask
  end

  def hits(question)
    listas = terms(question).map { |term| search(term).first(PER_TERM) }
    Rails.logger.info "[KBase] 🔎 Foro sin búsqueda semántica → búsqueda normal: #{terms(question).join(' · ')}"
    Array.new(listas.map(&:size).max.to_i) { |i| listas.pluck(i) }.flatten.compact.uniq { |hit| hit[:post_id] }
  end

  def terms(question)
    @terms ||= {}
    @terms[question] ||= (ai_terms(question).presence || [plain_terms(question)]).compact_blank.first(MAX_TERMS)
  end

  private

  def ai_terms(question)
    texto = @ask.call([
                        { role: 'system',
                          content: 'Devuelve de 1 a 3 búsquedas cortas (1 a 3 palabras cada una, sin artículos ni signos) para ' \
                                   'encontrar en un foro de conocimiento lo que pregunta el mensaje. Una por línea, sin numerar.' },
                        { role: 'user', content: question.to_s.truncate(500) }
                      ])
    texto.to_s.lines.map { |l| l.gsub(/\A[\s\-*•\d.)]+|["«»]/, '').strip }.compact_blank
  end

  # Sin IA: las dos primeras palabras con contenido.
  def plain_terms(question)
    question.to_s.downcase.scan(/[[:alnum:]áéíóúñü]+/).reject { |w| w.length < 3 || STOPWORDS.include?(w) }.first(2).join(' ')
  end

  def search(term)
    uri = URI("#{@url}/search.json")
    uri.query = URI.encode_www_form(q: term)
    respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request['Api-Key'] = @api_key if @api_key.present?
      request['Api-Username'] = @username
      http.request(request)
    end
    return [] unless respuesta.is_a?(Net::HTTPSuccess)

    self.class.to_hits(JSON.parse(respuesta.body), @url)
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Búsqueda normal del foro («#{term}»): #{e.message}"
    []
  end
end
