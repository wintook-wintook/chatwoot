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
    'max_results' => 3,
    'max_context_chars' => 6000
  }.freeze

  # Configuración para modo Discourse
  MAX_RESULTS    = 3
  MAX_HISTORY    = 6
  # Por item recuperado. 3 items x 2000 = el tope de max_context_chars (6000).
  MAX_ITEM_CHARS = 2000
  MAX_POST_CHARS = 2000

  # `branch:` — rama ya decidida por el job (@ruta). Se recibe para no clasificar dos
  # veces y pagar dos llamadas al LLM en el mismo turno. `:auto` = clasificar aquí.
  def initialize(message, tracking: nil, branch: :auto)
    @branch       = branch
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

    question     = @message.content.strip
    @search_text = search_query(question)
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

  # Un turno de seguimiento ("y para 20?", "y eso cuánto sale?") no tiene contenido
  # semántico propio: buscar solo con él devuelve resultados al azar — para "y para
  # 20?" la búsqueda traía SALUDOS DE CORTESIA en vez de la tabla de precios — y el
  # modelo acaba respondiendo de memoria e inventando la cifra. En ese caso la
  # consulta hereda el tema de los mensajes anteriores del cliente; la pregunta
  # original no se toca, esto solo alimenta la búsqueda.
  #
  # Se detecta por conector inicial, demostrativo sin antecedente, o una o dos
  # palabras. Contar palabras a secas no sirve: "trabajan los domingos?" es igual de
  # corta pero sí trae tema propio, y enriquecerla solo le mete ruido.
  CONTINUATION_RE    = /\A\s*(?:¿\s*)?(?:y|e|o|pero|entonces|tambi[eé]n)\b/i
  ANAPHORA_RE        = /\b(?:eso|esa|ese|esos|esas|aquello|lo mismo)\b/i
  MAX_FOLLOWUP_WORDS = 8

  def follow_up?(question)
    words = question.to_s.split.size
    return false if words.zero? || words > MAX_FOLLOWUP_WORDS
    return true if words <= 2

    question.match?(CONTINUATION_RE) || question.match?(ANAPHORA_RE)
  end

  def search_query(question)
    return question unless follow_up?(question)
    return question if @conversation.blank?

    # reorder, no order: la asociación messages ya trae su propio ORDER BY y un
    # order() encadenado se suma detrás en vez de reemplazarlo — devolvía siempre
    # los dos mensajes más viejos de la conversación en vez de los dos anteriores.
    previous = @conversation.messages.incoming
                            .where('id < ?', @message.id)
                            .reorder(id: :desc).limit(2)
                            .pluck(:content).compact_blank
    return question if previous.empty?

    enriched = "#{previous.reverse.join(' ')} #{question}".truncate(500)
    Rails.logger.info "[KBase] 🧵 Turno corto → búsqueda con contexto: #{enriched.truncate(120)}"
    enriched
  end

  # ==============================================================================
  # Detección de directiva
  # ==============================================================================

  # @ruta — si el agente declara rutas por rama, la fuente la elige la rama del turno y
  # no la precedencia del catálogo. Sin rutas declaradas, el comportamiento de siempre.
  def detect_directive
    cp = @tracking&.complementary_prompt.to_s
    route_map = ContactTrackings::RouteMap.parse(cp)
    return directive_for_branch(route_map) if route_map.present?

    KnowledgeBase::Directives.detect(cp)
  end

  # Clasifica el turno en una de las ramas declaradas y devuelve SOLO la directiva de
  # esa rama. Una rama sin fuente (guion) devuelve nil: el turno sigue al conversacional.
  def directive_for_branch(route_map)
    route = if @branch == :auto
              ContactTrackings::BranchClassifierService.new(
                @tracking, @message, route_map, recent_context: recent_context_for_branch
              ).classify
            else
              @branch
            end
    return nil if route.nil? || !route.source?

    directive = KnowledgeBase::Directives.detect(route.directive)
    Rails.logger.info "[KBase] 🧭 Rama '#{route.name}' → #{directive.inspect}"
    directive
  end

  def recent_context_for_branch
    return '' if @conversation.blank?

    @conversation.messages.where(message_type: %i[incoming outgoing])
                 .where('id < ?', @message.id).order(id: :desc).limit(4)
                 .reverse.map { |m| "#{m.incoming? ? 'Cliente' : 'Asesor'}: #{m.content.to_s.truncate(120)}" }
                 .join("\n")
  rescue StandardError
    ''
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
    embedding = generate_embedding_openai(@search_text || question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(source_type: source_type)
                    .search_by_embedding(
                      embedding,
                      limit: kbase_setting('max_results'),
                      threshold: kbase_setting('similarity_threshold')
                    )

    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en #{source_type}"
      return false
    end

    Rails.logger.info "[KBase] ✅ #{items.size} resultado(s) en #{source_type}"

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
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

    embedding = generate_embedding_openai(@search_text || question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(knowledge_source_id: source.id)
                    .search_by_embedding(
                      embedding,
                      limit: kbase_setting('max_results'),
                      threshold: kbase_setting('similarity_threshold')
                    )
    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en Google Doc '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
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
    embedding = generate_embedding_openai(@search_text || question)
    return false unless embedding

    items = @account.knowledge_items
                    .where(knowledge_source_id: source.id)
                    .search_by_embedding(embedding, limit: kbase_setting('max_results'), threshold: kbase_setting('similarity_threshold'))
    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en hoja FAQ '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
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

    first_name = @message.sender&.name&.split&.first || 'cliente'
    header     = agent_system_prompt || <<~SYSTEM.strip
      Eres un asesor de #{@account.name}. Responde como un humano amable y conocedor.
      NUNCA menciones que eres un bot ni que consultaste una base de datos.
    SYSTEM
    objective     = @tracking&.objective.to_s
    system_prompt = objective.present? ? "#{header}\n\nObjetivo de la conversación: #{objective}" : header

    user_prompt = <<~USER.strip
      El cliente #{first_name} preguntó: "#{question.truncate(300)}"

      Información relevante:
      #{context}

      Respondé usando esa información de forma completa y útil. Tono natural y conversacional.
      No uses prefijos como "Asesor:" ni comillas al inicio o final.
    USER

    history  = load_history
    messages = [{ role: 'system', content: system_prompt }]
    history.each do |h|
      messages << { role: 'user',      content: h['q'] }
      messages << { role: 'assistant', content: h['a'] }
    end
    messages << { role: 'user', content: user_prompt }

    reply = call_openai_simple(messages, max_tokens: 800)
            &.gsub(/\A[A-Za-záéíóúñÁÉÍÓÚÑ\s]{2,20}:\s*\n?/, '')
            &.strip
    return nil if reply.blank?

    reply = strip_echoed_sources(reply)
    save_history(history, question, reply)
    reply
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

    result = search_discourse(@search_text || question, source.config)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ Sin resultados en Discourse → sin respuesta'
      return false
    end

    history = load_history
    answer  = ask_openai_with_history(question, result[:context], history)
    return false if answer.blank?

    answer = strip_echoed_sources(answer)
    save_history(history, question, answer)

    footer = build_sources_footer(result[:sources], question, answer)
    send_reply(footer.present? ? "#{answer}#{footer}" : answer)
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

    result = search_discourse(@search_text || question, hook.settings)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ @discourse: sin resultados → sin respuesta'
      return false
    end

    history = load_history
    answer  = ask_openai_with_history(question, result[:context], history)
    return false if answer.blank?

    answer = strip_echoed_sources(answer)
    save_history(history, question, answer)

    footer = build_sources_footer(result[:sources], question, answer)
    send_reply(footer.present? ? "#{answer}#{footer}" : answer)
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
      sleep(1.5) if idx.positive? # evitar rate limit entre fetches consecutivos

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
    return '' if post_id.blank?

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

  # El prompt del agente (complementary_prompt) es donde viven sus reglas: tono,
  # regla de evidencia, prohibición de diagnosticar, nombres exactos, etiquetas.
  # Antes solo lo recibía la rama de Discourse; la rama pgvector se quedaba con el
  # objetivo y respondía sin ninguna de esas reglas. Ahora ambas parten del mismo
  # texto, para que el agente se comporte igual sin importar de dónde salió la
  # información.
  def agent_system_prompt
    return nil if @tracking&.complementary_prompt.blank?

    # @ruta — las líneas de configuración se quitan ANTES que nada: en un agente
    # con rutas viven ahí las directivas de TODAS las ramas, y no deben llegar al
    # modelo (ni de rebote al cliente). Las directivas sueltas se quitan también:
    # son configuración, no instrucciones para el modelo.
    ContactTrackings::RouteMap.strip(@tracking.complementary_prompt)
                              .gsub(/@buscar_foro\([^)]+\)/i, '')
                              .gsub(/@buscar_predefinidas\b/i, '')
                              .gsub(/@buscar_art[ií]culo\b/i, '')
                              .gsub(/@discourse\b/i, '')
                              .strip
                              .presence
  end

  def build_messages(question, context, history)
    system_content = agent_system_prompt || <<~PROMPT.strip
      Eres un agente de soporte de #{@account.name}. Respondé preguntas
      de forma conversacional y concisa, como lo haría un experto de soporte.
      - Usá el contenido del foro como referencia, respondé con tus propias palabras.
      - Si necesitás más información, hacé UNA pregunta de seguimiento.
      - Respondé en el mismo idioma que el cliente.
      - No menciones que consultaste un foro o base de conocimiento.
    PROMPT

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

  # GPT tiende a imitar el footer de fuentes cuando lo ve en turnos previos del
  # historial (kb_history guardaba la respuesta ya con el footer horneado adentro),
  # generando su propio link — a veces el equivocado — antes de que agreguemos el
  # nuestro. Lo quitamos del texto del modelo para mostrar un solo link, siempre
  # el elegido por build_sources_footer.
  def strip_echoed_sources(text)
    text.split("\n").reject do |line|
      line.match?(/^\s*📚/) ||
        line.match?(/^\s*fuentes relacionadas:?\s*$/i) ||
        line.match?(%r{^\s*[-*]?\s*https?://\S+\s*$}i)
    end.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # Un solo término compartido no acredita que la fuente venga al caso: para "tengo un
  # error al facturar" el foro devolvía "Contpaq Comercial Premium no respeta los
  # descuentos de Kontrolya al facturar" y ganaba con la palabra "facturar" suelta.
  MIN_SOURCE_OVERLAP = 2

  # Relleno conversacional que aparece por igual en cualquier respuesta y en cualquier
  # título; contarlo infla el parecido sin decir nada del tema.
  STOPWORDS = %w[
    para como esta este esto pero mas muy todo toda cuando donde desde sobre
    tiene tienes puede puedes hacer favor gracias hola necesito necesitas
    informacion información problema deseas quieres
    que los las con por del una uno sus sin son esa ese hay ver dos the and
  ].to_set.freeze

  # Se cuentan tokens de 3+ con dígitos incluidos: los códigos de error ("Z07", "Z08")
  # y las siglas ("SAE", "PDF") son justo lo que distingue un hilo del de al lado, y
  # con un filtro de solo-letras-de-4+ quedaban invisibles — "Error Z07 licencia de uso
  # no autorizada" y "Error Z08 licencia de uso no autorizada" empataban y ganaba el
  # primero de la lista.
  def significant_words(text)
    text.to_s.downcase.scan(/[a-záéíóúñü0-9]{3,}/).to_set - STOPWORDS
  end

  def build_sources_footer(sources, question = nil, answer = nil)
    return '' if sources.empty?

    return "\n\n📚 Más información: #{sources.first[:url]}" if question.blank?

    # El ranking de Discourse no siempre coincide con la fuente que GPT usó para
    # redactar (preguntas parafraseadas rankean peor que las que calcan el título),
    # así que elegimos por overlap de palabras. Se puntúa contra la pregunta Y contra
    # la respuesta: si el modelo se limitó a pedir una aclaración no usó ninguna
    # fuente, y citar una es peor que no citar nada.
    words = significant_words("#{question} #{answer}")

    best    = sources.max_by { |source| (words & significant_words(source[:title])).size }
    overlap = (words & significant_words(best[:title])).size

    Rails.logger.info "[KBase] 🔗 Mejor fuente '#{best[:title].truncate(40)}': #{overlap} palabras overlap"
    return '' if overlap < MIN_SOURCE_OVERLAP

    "\n\n📚 Más información: #{best[:url]}"
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
      model: ENV.fetch('OPENAI_GPT_MODEL', 'gpt-4o-mini'),
      messages: messages,
      max_tokens: max_tokens,
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
