# frozen_string_literal: true

# Responde mensajes de contactos sin seguimiento activo usando Discourse como
# base de conocimiento y OpenAI para generar respuestas conversacionales.
class KnowledgeBaseResponseService
  MAX_RESULTS    = 3
  MAX_HISTORY    = 6
  MAX_POST_CHARS = 2000

  def initialize(message, tracking: nil)
    @message      = message
    @tracking     = tracking
    @contact      = message.conversation.contact
    @account      = message.account
    @inbox        = message.inbox
    @conversation = message.conversation
  end

  def perform
    return false unless kb_enabled?
    return false if @message.content.blank?

    question = @message.content.strip
    Rails.logger.info "[KnowledgeBase] 🔍 Pregunta: #{question.truncate(80)}"

    result   = search_discourse(question)
    if result[:context].blank?
      Rails.logger.info '[KnowledgeBase] ⚠️ Sin resultados en Discourse → sin respuesta'
      return false
    end

    history  = load_history
    answer   = ask_openai(question, result[:context], history)

    return false unless answer.present?

    footer = build_sources_footer(result[:sources], question)
    answer += footer if footer.present?

    save_history(history, question, answer)
    reply(answer)
    true
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] ❌ Error: #{e.message}"
    false
  end

  private

  # Hook de Discourse configurado para este inbox (con fallback a ENV)
  def discourse_hook
    @discourse_hook ||= @account.hooks.find_by(app_id: 'discourse', inbox_id: @inbox.id, status: 'enabled')
  end

  def discourse_url
    url = discourse_hook&.settings&.dig('url').presence || ENV.fetch('DISCOURSE_URL', '')
    url.chomp('/')
  end

  def discourse_api_key
    discourse_hook&.settings&.dig('api_key').presence || ENV.fetch('DISCOURSE_API_KEY', '')
  end

  def discourse_username
    discourse_hook&.settings&.dig('username').presence || ENV.fetch('DISCOURSE_USERNAME', 'system')
  end

  def kb_enabled?
    return false unless discourse_hook.present?

    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return false unless hook&.settings&.dig('api_key').present?

    true
  end

  # ---------------------------------------------------------------
  # Búsqueda semántica en Discourse (discourse-ai plugin)
  # Paso 1: semantic search → obtiene post IDs y blurbs
  # Paso 2: fetch_post_content → obtiene el Markdown completo de cada post
  # El contexto completo se inyecta al system prompt para RAG real
  # ---------------------------------------------------------------
  def search_discourse(query)
    require 'net/http'
    require 'json'

    uri       = URI("#{discourse_url}/discourse-ai/embeddings/semantic-search.json")
    uri.query = URI.encode_www_form(q: query)

    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = discourse_api_key if discourse_api_key.present?
    request['Api-Username'] = discourse_username
    request['Content-Type'] = 'application/json'

    response  = http.request(request)
    data      = JSON.parse(response.body)

    posts     = data['posts']  || []
    topics    = data['topics'] || []
    topic_map = topics.index_by { |t| t['id'] }

    Rails.logger.info "[KnowledgeBase] 📚 #{posts.size} resultados en semantic-search"

    if ENV.fetch('TRACKING_DEBUG_TAG', 'false') == 'true'
      Rails.logger.debug "[KnowledgeBase] 🔬 RAW semantic-search: #{data.to_json.truncate(800)}"
    end

    sources = []
    context = posts.first(MAX_RESULTS).filter_map do |post|
      topic = topic_map[post['topic_id']]
      next unless topic

      post_id = post['id']
      title   = topic['title'].to_s.strip
      blurb   = post['blurb'].to_s.strip
      slug    = topic['slug'].to_s
      tid     = topic['id'].to_s
      url     = "#{discourse_url}/t/#{slug}/#{tid}"

      # Obtener contenido completo del post (RAG real)
      full_content = fetch_post_content(post_id)
      content      = full_content.presence || blurb

      Rails.logger.info "[KnowledgeBase]   📄 post##{post_id} — #{title.truncate(50)}"
      Rails.logger.info "[KnowledgeBase]      blurb:  #{blurb.truncate(80)}"
      Rails.logger.info "[KnowledgeBase]      full:   #{content.truncate(120)} (#{content.length} chars)"

      sources << { title: title, url: url }
      "## #{title}\n#{content}\nFuente: #{url}"
    end.join("\n\n")

    Rails.logger.info "[KnowledgeBase] 📝 Contexto total inyectado: #{context.length} chars"

    { context: context, sources: sources }
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] ❌ Error buscando en Discourse: #{e.message}"
    { context: '', sources: [] }
  end

  # ---------------------------------------------------------------
  # Obtiene el Markdown completo de un post vía API de Discourse
  # Endpoint: GET /posts/{post_id}.json
  # Retorna el campo `raw` (Markdown original), truncado a MAX_POST_CHARS
  # ---------------------------------------------------------------
  def fetch_post_content(post_id)
    return '' unless post_id.present?

    uri               = URI("#{discourse_url}/posts/#{post_id}.json")
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.read_timeout = 8

    request                  = Net::HTTP::Get.new(uri)
    request['Api-Key']       = discourse_api_key if discourse_api_key.present?
    request['Api-Username']  = discourse_username
    request['Content-Type']  = 'application/json'

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "[KnowledgeBase] ⚠️ post##{post_id} retornó HTTP #{response.code}"
      return ''
    end

    post_data = JSON.parse(response.body)
    raw       = post_data['raw'].to_s.strip

    if ENV.fetch('TRACKING_DEBUG_TAG', 'false') == 'true'
      Rails.logger.debug "[KnowledgeBase] 🔬 RAW post##{post_id}: #{raw.truncate(400)}"
    end

    raw.truncate(MAX_POST_CHARS)
  rescue StandardError => e
    Rails.logger.warn "[KnowledgeBase] ⚠️ No se pudo obtener post##{post_id}: #{e.message}"
    ''
  end

  # ---------------------------------------------------------------
  # Historial de conversación almacenado en conversation.additional_attributes
  # ---------------------------------------------------------------
  def history_key
    'kb_history'
  end

  def load_history
    @conversation.additional_attributes&.dig(history_key) || []
  end

  def save_history(history, question, answer)
    history << { 'q' => question, 'a' => answer }
    history = history.last(MAX_HISTORY)

    attrs = (@conversation.additional_attributes || {}).merge(history_key => history)
    @conversation.update_columns(additional_attributes: attrs)
  rescue StandardError => e
    Rails.logger.warn "[KnowledgeBase] ⚠️ No se pudo guardar historial: #{e.message}"
  end

  # ---------------------------------------------------------------
  # Llamada a OpenAI
  # ---------------------------------------------------------------
  def ask_openai(question, context, history)
    hook    = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    api_key = hook.settings['api_key']

    require 'net/http'
    require 'json'

    uri               = URI('https://api.openai.com/v1/chat/completions')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 30

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = {
      model:       ENV.fetch('OPENAI_GPT_MODEL', 'gpt-4o-mini'),
      messages:    build_messages(question, context, history),
      max_tokens:  600,
      temperature: 0.5
    }.to_json

    response = http.request(request)
    result   = JSON.parse(response.body)
    result.dig('choices', 0, 'message', 'content')&.strip
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] ❌ Error OpenAI: #{e.message}"
    nil
  end

  def build_messages(question, context, history)
    system_content = if @tracking&.complementary_prompt.present?
      # Strip @discourse markers — GPT ya tiene el contexto inyectado, no debe
      # interpretar @discourse como un comando a escribir literalmente
      @tracking.complementary_prompt.gsub(/@discourse\b[^\n]*/i, '').strip
    else
      <<~PROMPT.strip
        Eres un agente de soporte técnico de #{@account.name}. Tu función es responder
        preguntas de clientes de forma conversacional, clara y guiada, como lo haría
        un experto de soporte.

        Reglas:
        - Usá el contenido del foro como referencia, pero respondé con tus propias palabras.
        - No copies textualmente los artículos del foro.
        - Si necesitás más información para responder con precisión, hacé UNA pregunta de seguimiento.
        - Respondé en el mismo idioma que el cliente.
        - Sé conciso. Si hay pasos, enuméralos.
        - No menciones que consultaste un foro o base de conocimiento.
      PROMPT
    end

    system_content += "\n\nContenido relevante del foro:\n#{context}" if context.present?


    messages = [{ role: 'system', content: system_content }]
    history.each do |h|
      messages << { role: 'user',      content: h['q'] }
      messages << { role: 'assistant', content: h['a'] }
    end
    messages << { role: 'user', content: question }
    messages
  end

  def build_sources_footer(sources, question = nil)
    return '' if sources.empty?

    top = sources.first
    return "\n\n📚 Más información: #{top[:url]}" unless question.present?

    question_words = question.downcase.scan(/[a-záéíóúñü]{4,}/).to_set
    title_words    = top[:title].downcase.scan(/[a-záéíóúñü]{4,}/).to_set
    overlap        = (question_words & title_words).size

    Rails.logger.info "[KnowledgeBase] 🔗 Overlap con fuente '#{top[:title].truncate(40)}': #{overlap} palabras"

    return '' if overlap.zero?

    "\n\n📚 Más información: #{top[:url]}"
  end

  # ---------------------------------------------------------------
  # Enviar respuesta al contacto en la conversación
  # ---------------------------------------------------------------
  def reply(text)
    bot_user = @account.users.first
    text = "#{text}\n\n@KBase" if ENV.fetch('TRACKING_DEBUG_TAG', 'false') == 'true'

    @conversation.messages.create!(
      account_id:         @account.id,
      inbox_id:           @inbox.id,
      message_type:       :outgoing,
      content:            text,
      private:            false,
      sender:             bot_user,
      content_attributes: { 'bot_reply' => true }
    )
    Rails.logger.info '[KnowledgeBase] ✅ Respuesta enviada → respondió KBase'
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] ❌ Error enviando respuesta: #{e.message}"
  end
end
