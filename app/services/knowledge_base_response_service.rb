# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - BASE DE CONOCIMIENTO
# ================================================================================
# Cuatro modos según la directiva en complementary_prompt:
#
#   @buscar_predefinidas          → pgvector sobre knowledge_items (Respuestas predefinidas)
#   @buscar_articulo              → pgvector sobre knowledge_items (artículos del Centro de Ayuda)
#   @buscar_foro(nombre_fuente)   → Discourse AI semantic search via KnowledgeSource
#   @discourse                    → Discourse AI semantic search via integración del inbox
#
# RETORNO: true si se envió respuesta, false si no hay resultados o error.
# ================================================================================

class KnowledgeBaseResponseService
  # Configuración para modo pgvector (canned responses)
  DEFAULTS = {
    'similarity_threshold' => 0.20,
    'max_results'          => 3,
    'max_context_chars'    => 6000
  }.freeze

  # Configuración para modo Discourse
  MAX_RESULTS    = 3
  MAX_HISTORY    = 6
  MAX_POST_CHARS = 2000

  def initialize(message, tracking: nil)
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @inbox        = message.inbox
    @conversation = message.conversation
  end

  def perform
    directive = detect_directive
    unless directive
      Rails.logger.info '[KBase] ⏭️  Sin directiva kbase → skip'
      return false
    end
    return false if @message.content.blank?

    question = @message.content.strip
    Rails.logger.info "[KBase] 🔍 Modo: #{directive[:mode]}#{" (#{directive[:source_name]})" if directive[:source_name]}"

    case directive[:mode]
    when :erp_query
      perform_erp_query
    when :canned_response
      perform_pgvector(question, 'canned_response')
    when :article
      perform_pgvector(question, 'article')
    when :knowledge_source
      perform_discourse(question, directive[:source_name])
    when :google_doc
      perform_google_doc(question, directive[:source_name])
    when :google_sheet
      perform_google_sheet(question, directive[:source_name])
    when :discourse_integration
      perform_discourse_integration(question)
    else
      false
    end
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    false
  end

  private

  # ==============================================================================
  # Detección de directiva
  # ==============================================================================

  def detect_directive
    cp = @tracking&.complementary_prompt.to_s
    # {{consulta:}} es interpolación determinista de datos del ERP; tiene prioridad y
    # puede aparecer varias veces mezclada con texto en la misma plantilla.
    return { mode: :erp_query } if ExternalDb::ConsultaDirectiveRenderer.contains?(cp)

    detect_search_directive(cp)
  end

  def detect_search_directive(prompt)
    if prompt.match?(/@buscar_predefinidas\b/i)
      { mode: :canned_response }
    elsif prompt.match?(/@buscar_art[ií]culo\b/i)
      { mode: :article }
    elsif (match = prompt.match(/@buscar_foro\(([^)]+)\)/i))
      { mode: :knowledge_source, source_name: match[1].strip }
    elsif (match = prompt.match(/\{\{doc:([^}]+)\}\}/i))
      { mode: :google_doc, source_name: match[1].strip }
    elsif (match = prompt.match(/\{\{hoja:([^}]+)\}\}/i))
      { mode: :google_sheet, source_name: match[1].strip }
    elsif prompt.match?(/@discourse\b/i)
      { mode: :discourse_integration }
    end
  end

  # Las fuentes Google (Doc/Sheet) reutilizan la conexión de Google Calendar:
  # si la cuenta no tiene esa feature, las directivas {{doc:}}/{{hoja:}} no operan.
  def google_feature_enabled?
    @account.feature_enabled?('google_calendar')
  end

  # ==============================================================================
  # MODO {{consulta:}} — interpolación determinista de datos del ERP (Bot Cobrador).
  # Reemplaza cada {{consulta:...}} de la plantilla por el resultado de la consulta
  # predefinida y envía el texto ya interpolado. Sin IA, fail-soft, scoped a la cuenta.
  # ==============================================================================
  def perform_erp_query
    template = @tracking&.complementary_prompt.to_s
    rendered = ExternalDb::ConsultaDirectiveRenderer.new(
      account: @account, contact: @conversation&.contact, inbox: @inbox
    ).render(template).strip

    if rendered.blank?
      Rails.logger.info '[KBase] ⚠️ {{consulta:}} no produjo texto → sin respuesta'
      return false
    end

    send_reply(rendered)
    true
  end

  # ==============================================================================
  # MODO 1 — pgvector local (Respuestas predefinidas / artículos del Centro de Ayuda)
  # ==============================================================================

  def perform_pgvector(question, source_type)
    embedding = generate_embedding_openai(question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(source_type: source_type)
                    .search_by_embedding(
                      embedding,
                      limit:     kbase_setting('max_results'),
                      threshold: kbase_setting('similarity_threshold')
                    )

    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en #{source_type}"
      return false
    end

    Rails.logger.info "[KBase] ✅ #{items.size} resultado(s) en #{source_type}"

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(1200)}" }
                   .join("\n\n")
                   .truncate(kbase_setting('max_context_chars'))

    reply_text = generate_contextual_reply(question, context)
    return false if reply_text.blank?

    source_tag = @account.knowledge_sources.find_by(source_type: source_type)&.name ||
                 I18n.t("knowledge_sources.names.#{source_type}", locale: @account.locale.presence || I18n.default_locale)
    send_reply("#{reply_text}\n\n_#{source_tag}_")
    true
  end

  # ==============================================================================
  # MODO Google Doc — pgvector local scoped a UNA fuente (por nombre único)
  # Directiva {{doc:nombre}}. A diferencia de @buscar_predefinidas/@buscar_articulo
  # (que filtran por source_type), aquí se filtra por knowledge_source_id porque
  # puede haber varios Google Docs y el nombre direcciona a uno concreto.
  # ==============================================================================

  def perform_google_doc(question, source_name)
    return false unless google_feature_enabled?

    source = @account.knowledge_sources.active
                     .where(source_type: 'google_doc')
                     .where('LOWER(name) = LOWER(?)', source_name)
                     .first
    unless source
      Rails.logger.warn "[KBase] ⚠️ Google Doc '#{source_name}' no encontrado o inactivo"
      return false
    end

    embedding = generate_embedding_openai(question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(knowledge_source_id: source.id)
                    .search_by_embedding(
                      embedding,
                      limit:     kbase_setting('max_results'),
                      threshold: kbase_setting('similarity_threshold')
                    )
    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en Google Doc '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(1200)}" }
                   .join("\n\n")
                   .truncate(kbase_setting('max_context_chars'))

    reply_text = generate_contextual_reply(question, context)
    return false if reply_text.blank?

    send_reply("#{reply_text}\n\n_#{source.name}_")
    true
  end

  # ==============================================================================
  # MODO Google Sheet — directiva {{hoja:nombre}}
  #   modo FAQ  → pgvector scoped a la fuente (igual que Google Doc).
  #   modo Datos→ SheetQueryService: LLM traduce la pregunta y Ruby calcula exacto.
  # ==============================================================================

  def perform_google_sheet(question, source_name)
    return false unless google_feature_enabled?

    source = @account.knowledge_sources.active
                     .where(source_type: 'google_sheet')
                     .where('LOWER(name) = LOWER(?)', source_name)
                     .first
    unless source
      Rails.logger.warn "[KBase] ⚠️ Google Sheet '#{source_name}' no encontrado o inactivo"
      return false
    end

    return perform_sheet_faq(question, source) unless source.config['sheet_mode'] == 'data'

    perform_sheet_data(question, source)
  end

  def perform_sheet_data(question, source)
    result = SheetQueryService.new(source, question, @account).perform
    if result.blank?
      Rails.logger.info "[KBase] ⚠️ Sin resultado en hoja de datos '#{source.name}'"
      return false
    end

    # El número/resultado lo calcula Ruby (exacto); el LLM solo lo redacta natural.
    reply_text = generate_contextual_reply(question, "Resultado exacto a comunicar: #{result}")
    reply_text = result if reply_text.blank?
    send_reply("#{reply_text}\n\n_#{source.name}_")
    true
  end

  def perform_sheet_faq(question, source)
    embedding = generate_embedding_openai(question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(knowledge_source_id: source.id)
                    .search_by_embedding(embedding, limit: kbase_setting('max_results'), threshold: kbase_setting('similarity_threshold'))
    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en hoja FAQ '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(1200)}" }
                   .join("\n\n")
                   .truncate(kbase_setting('max_context_chars'))
    reply_text = generate_contextual_reply(question, context)
    return false if reply_text.blank?

    send_reply("#{reply_text}\n\n_#{source.name}_")
    true
  end

  def generate_contextual_reply(question, context)
    api_key = openai_api_key
    return nil unless api_key

    first_name    = @message.sender&.name&.split&.first || 'cliente'
    objective     = @tracking&.objective.to_s
    system_prompt = <<~SYSTEM.strip
      Eres un asesor de #{@account.name}. Responde como un humano amable y conocedor.
      NUNCA menciones que eres un bot ni que consultaste una base de datos.
      #{objective.present? ? "Objetivo de la conversación: #{objective}" : ""}
    SYSTEM

    user_prompt = <<~USER.strip
      El cliente #{first_name} preguntó: "#{question.truncate(300)}"

      Información relevante:
      #{context}

      Respondé usando esa información de forma completa y útil. Tono natural y conversacional.
      No uses prefijos como "Asesor:" ni comillas al inicio o final.
    USER

    call_openai_simple([
      { role: 'system', content: system_prompt },
      { role: 'user',   content: user_prompt }
    ], max_tokens: 800)
      &.gsub(/\A[A-Za-záéíóúñÁÉÍÓÚÑ\s]{2,20}:\s*\n?/, '')
      &.strip
  end

  # ==============================================================================
  # MODO 2 — Discourse AI semantic search
  # ==============================================================================

  def perform_discourse(question, source_name)
    source = @account.knowledge_sources.active
                     .where('LOWER(name) = LOWER(?)', source_name)
                     .first
    unless source
      Rails.logger.warn "[KBase] ⚠️ KnowledgeSource '#{source_name}' no encontrado o inactivo"
      return false
    end

    result = search_discourse(question, source.config)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ Sin resultados en Discourse → sin respuesta'
      return false
    end

    history    = load_history
    answer     = ask_openai_with_history(question, result[:context], history)
    return false unless answer.present?

    footer = build_sources_footer(result[:sources], question)
    answer += footer if footer.present?

    save_history(history, question, answer)
    send_reply(answer)
    true
  end

  # ==============================================================================
  # MODO 3 — Discourse integration (hook configurado por inbox)
  # ==============================================================================

  def perform_discourse_integration(question)
    hook = @account.hooks.find_by(app_id: 'discourse', inbox_id: @inbox.id, status: 'enabled')
    unless hook
      Rails.logger.warn '[KBase] ⚠️ @discourse: no hay integración Discourse activa para este inbox'
      return false
    end

    result = search_discourse(question, hook.settings)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ @discourse: sin resultados → sin respuesta'
      return false
    end

    history = load_history
    answer  = ask_openai_with_history(question, result[:context], history)
    return false unless answer.present?

    footer = build_sources_footer(result[:sources], question)
    answer += footer if footer.present?

    save_history(history, question, answer)
    send_reply(answer)
    true
  end

  # Llama al endpoint de Discourse AI semantic search y obtiene el contenido completo
  def search_discourse(query, config)
    url      = config['url'].to_s.chomp('/')
    api_key  = config['api_key'].to_s
    username = config['username'].presence || 'system'

    uri       = URI("#{url}/discourse-ai/embeddings/semantic-search.json")
    uri.query = URI.encode_www_form(q: query)

    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = api_key if api_key.present?
    request['Api-Username'] = username
    request['Content-Type'] = 'application/json'

    response  = http.request(request)
    data      = JSON.parse(response.body)
    posts     = data['posts']  || []
    topics    = data['topics'] || []
    topic_map = topics.index_by { |t| t['id'] }

    Rails.logger.info "[KBase] 📚 #{posts.size} resultado(s) en Discourse semantic-search"

    sources = []
    context = posts.first(MAX_RESULTS).each_with_index.filter_map do |post, idx|
      sleep(1.5) if idx.positive?  # evitar rate limit entre fetches consecutivos

      topic = topic_map[post['topic_id']]
      next unless topic

      post_id  = post['id']
      title    = topic['title'].to_s.strip
      post_url = "#{url}/t/#{topic['slug']}/#{topic['id']}"

      full_content = fetch_post_content(post_id, url, api_key, username)
      content      = full_content.presence || post['blurb'].to_s.strip
      next if content.blank?

      Rails.logger.info "[KBase]   📄 post##{post_id} — #{title.truncate(50)} (#{content.length} chars)"

      sources << { title: title, url: post_url }
      "## #{title}\n#{content}\nFuente: #{post_url}"
    end.join("\n\n")

    { context: context, sources: sources }
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error en Discourse search: #{e.message}"
    { context: '', sources: [] }
  end

  # GET /posts/:id.json → campo `raw` (Markdown original)
  def fetch_post_content(post_id, url, api_key, username)
    return '' unless post_id.present?

    uri               = URI("#{url}/posts/#{post_id}.json")
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.read_timeout = 8

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = api_key if api_key.present?
    request['Api-Username'] = username
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "[KBase] ⚠️ post##{post_id} retornó HTTP #{response.code}"
      return ''
    end

    JSON.parse(response.body)['raw'].to_s.strip.truncate(MAX_POST_CHARS)
  rescue StandardError => e
    Rails.logger.warn "[KBase] ⚠️ No se pudo obtener post##{post_id}: #{e.message}"
    ''
  end

  # ==============================================================================
  # Historial de conversación (guardado en conversation.additional_attributes)
  # ==============================================================================

  def load_history
    @conversation.additional_attributes&.dig('kb_history') || []
  end

  def save_history(history, question, answer)
    history << { 'q' => question, 'a' => answer }
    history  = history.last(MAX_HISTORY)
    attrs    = (@conversation.additional_attributes || {}).merge('kb_history' => history)
    @conversation.update_columns(additional_attributes: attrs)
  rescue StandardError => e
    Rails.logger.warn "[KBase] ⚠️ No se pudo guardar historial: #{e.message}"
  end

  # ==============================================================================
  # OpenAI — con historial (para Discourse)
  # ==============================================================================

  def ask_openai_with_history(question, context, history)
    api_key = openai_api_key
    return nil unless api_key

    call_openai_simple(build_messages(question, context, history), max_tokens: 600)
  end

  def build_messages(question, context, history)
    # Usa complementary_prompt si existe, limpiando la directiva @buscar_foro
    system_content = if @tracking&.complementary_prompt.present?
                       @tracking.complementary_prompt
                                .gsub(/@buscar_foro\([^)]+\)/i, '')
                                .gsub(/@discourse\b/i, '')
                                .strip
                     else
                       <<~PROMPT.strip
                         Eres un agente de soporte de #{@account.name}. Respondé preguntas
                         de forma conversacional y concisa, como lo haría un experto de soporte.
                         - Usá el contenido del foro como referencia, respondé con tus propias palabras.
                         - Si necesitás más información, hacé UNA pregunta de seguimiento.
                         - Respondé en el mismo idioma que el cliente.
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

  # ==============================================================================
  # Footer de fuentes
  # ==============================================================================

  def build_sources_footer(sources, question = nil)
    return '' if sources.empty?

    top = sources.first
    return "\n\n📚 Más información: #{top[:url]}" unless question.present?

    question_words = question.downcase.scan(/[a-záéíóúñü]{4,}/).to_set
    title_words    = top[:title].downcase.scan(/[a-záéíóúñü]{4,}/).to_set
    overlap        = (question_words & title_words).size

    Rails.logger.info "[KBase] 🔗 Overlap fuente '#{top[:title].truncate(40)}': #{overlap} palabras"
    return '' if overlap.zero?

    "\n\n📚 Más información: #{top[:url]}"
  end

  # ==============================================================================
  # Envío de respuesta
  # ==============================================================================

  def send_reply(text)
    reply_message = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      { content: text, private: false }
    ).perform

    if reply_message.present?
      reply_message.content_attributes[:sentiment_auto_reply] = true
      reply_message.save!
    end
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error enviando respuesta: #{e.message}"
  end

  # ==============================================================================
  # Utilidades
  # ==============================================================================

  def call_openai_simple(messages, max_tokens: 600)
    api_key = openai_api_key
    return nil unless api_key

    require 'net/http'
    require 'json'

    uri               = URI('https://api.openai.com/v1/chat/completions')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 45

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = {
      model:       ENV.fetch('OPENAI_GPT_MODEL', 'gpt-4o-mini'),
      messages:    messages,
      max_tokens:  max_tokens,
      temperature: 0.5
    }.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content')&.strip
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error OpenAI: #{e.message}"
    nil
  end

  def generate_embedding_openai(text)
    api_key = openai_api_key
    return nil unless api_key

    uri               = URI('https://api.openai.com/v1/embeddings')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 10

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error embedding: #{e.message}"
    nil
  end

  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end

  # Cada cuenta usa su propia integración OpenAI (sin fallback a ENV global, multi-tenant).
  def openai_api_key
    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end

  def kbase_setting(key)
    overrides = @account.custom_attributes&.dig('kbase_search') || {}
    value     = overrides[key.to_s]
    value.present? ? value.to_f : DEFAULTS[key.to_s]
  end
end
