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
  # Umbral para @buscar_predefinidas(GRUPO). El general (0.20) es deliberadamente
  # permisivo: sobre el corpus completo, traer algo flojo es mejor que no traer nada.
  # En un grupo pasa lo contrario. Un grupo es un corpus estrecho y hecho a proposito
  # -- las instrucciones de gestion, por ejemplo -- y ahi lo mas cercano SIEMPRE existe:
  # con una sola instruccion cargada, "necesito actualizar mis datos fiscales" recuperaba
  # el contrato de la cotizacion y el agente pedia licencias, correo y razon social para
  # una gestion que no tiene nada que ver. Medido sobre ese corpus: la gestion correcta da
  # similitud 0.650 y las ajenas 0.333, 0.287 y 0.081, asi que 0.45 las separa con margen.
  # Aqui no encontrar nada es un resultado util: significa "no hay instruccion para esto".
  GROUP_SIMILARITY_THRESHOLD = 0.45
  MAX_POST_CHARS = 2000

  # `branch:` — rama ya decidida por el job (@ruta). Se recibe para no clasificar dos
  # veces y pagar dos llamadas al LLM en el mismo turno. `:auto` = clasificar aquí.
  def initialize(message, tracking: nil, branch: :auto)
    @branch       = branch
    @route        = nil
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

    question      = @message.content.strip
    @search_texts = search_queries(question)
    Rails.logger.info "[KBase] 🔍 Modo: #{directive[:mode]}#{" (#{directive[:source_name]})" if directive[:source_name]}"

    case directive[:mode]
    when :erp_query
      perform_erp_query
    when :canned_response
      perform_pgvector(question, 'canned_response', directive[:group])
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

  # Un turno corto suele continuar el tema anterior sin nombrarlo, y buscar solo con él
  # trae documentación de otro asunto: "y para 20?" devolvía SALUDOS DE CORTESIA en vez
  # de la tabla de precios, y "no manda error solo no llega" hilos de entrega de correo
  # en vez del hilo de pedidos que se venía tratando.
  #
  # No se intenta adivinar cuál de las dos consultas es la buena: se buscan LAS DOS —la
  # pregunta tal cual y la pregunta con el tema heredado— y se entrelazan los resultados.
  # Antes era una sola consulta elegida por heurística, y la heurística fallaba en ambos
  # sentidos: enriquecer "trabajan los domingos?" le metía ruido, y no enriquecer "no
  # manda error solo no llega" le quitaba el sujeto. Buscando las dos, ninguno de los dos
  # errores puede ocurrir; el precio es una recuperación extra en los turnos cortos.
  CONTINUATION_RE    = /\A\s*(?:¿\s*)?(?:y|e|o|pero|entonces|tambi[eé]n)\b/i
  ANAPHORA_RE        = /\b(?:eso|esa|ese|esos|esas|aquello|lo mismo)\b/i
  MAX_FOLLOWUP_WORDS = 8

  # ¿Vale la pena la segunda recuperación? En los turnos cortos y en los que arrancan con
  # conector o llevan un demostrativo sin antecedente.
  def worth_inheriting_topic?(question)
    words = question.to_s.split.size
    return false if words.zero?
    return true if words <= MAX_FOLLOWUP_WORDS

    question.match?(CONTINUATION_RE) || question.match?(ANAPHORA_RE)
  end

  # La pregunta tal cual y, cuando aplica, la misma precedida del tema de los mensajes
  # anteriores del cliente. La pregunta original nunca se toca: esto solo alimenta la
  # búsqueda.
  def search_queries(question)
    return [question] unless worth_inheriting_topic?(question)
    return [question] if @conversation.blank?

    # reorder, no order: la asociación messages ya trae su propio ORDER BY y un
    # order() encadenado se suma detrás en vez de reemplazarlo — devolvía siempre
    # los dos mensajes más viejos de la conversación en vez de los dos anteriores.
    previous = @conversation.messages.incoming
                            .where('id < ?', @message.id)
                            .reorder(id: :desc).limit(2)
                            .pluck(:content).compact_blank
    return [question] if previous.empty?

    enriched = "#{previous.reverse.join(' ')} #{question}".truncate(500)
    Rails.logger.info "[KBase] 🧵 Turno corto → segunda búsqueda con contexto: #{enriched.truncate(120)}"
    [question, enriched]
  end

  # Entrelaza en vez de concatenar: concatenadas, las MAX_RESULTS primeras salen todas de
  # la primera consulta y la segunda no aporta nada. Alternando, ambas quedan representadas
  # dentro del tope.
  def interleave(lists)
    return [] if lists.empty?

    Array.new(lists.map(&:size).max.to_i) { |i| lists.pluck(i) }.flatten.compact
  end

  # Recupera con TODAS las consultas del turno sobre el mismo scope, entrelaza y deduplica.
  # nil = ninguna consulta pudo embeberse (fallo de API); [] = se buscó y no hubo nada.
  def search_items(scope, threshold: nil)
    threshold ||= kbase_setting('similarity_threshold')
    lists = Array(@search_texts).filter_map do |query|
      embedding = generate_embedding_openai(query)
      next if embedding.blank?

      scope.search_by_embedding(embedding, limit: kbase_setting('max_results'), threshold: threshold).to_a
    end
    return nil if lists.empty?

    interleave(lists).uniq(&:id).first(kbase_setting('max_results'))
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
    # Se guarda aunque la rama no tenga fuente: branch_scope_rule la necesita para
    # decirle al modelo qué se decidió (ver agent_system_prompt).
    @route = route
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

  # Reparte el corpus de respuestas predefinidas entre ramas: @buscar_predefinidas(GESTION)
  # trae solo las que se llaman asi, y (!GESTION) todas las demas. Se filtra en SQL, antes
  # de la busqueda vectorial, asi que no cuesta una consulta extra: entra como WHERE en la
  # misma query.
  #
  # El grupo es un PREFIJO del nombre de la respuesta predefinida (su short_code, que es
  # lo que se vectoriza como titulo). Se eligio una convencion de nombre y no una columna
  # nueva para no pedir migracion ni cambios de pantalla: renombrar la respuesta basta.
  def grouped_items(source_type, group)
    scope = @account.knowledge_items.where(source_type: source_type)
    return scope if group.blank?

    negated = group.start_with?('!')
    name    = group.delete_prefix('!').strip
    return scope if name.blank?

    pattern = "#{ActiveRecord::Base.sanitize_sql_like(name)}%"
    Rails.logger.info "[KBase] \u{1F5C2}\uFE0F Grupo #{negated ? 'excluido' : 'exigido'}: #{name}"

    # title IS NULL en la rama negada: un NOT ILIKE contra NULL da NULL y descartaria el
    # item en silencio.
    negated ? scope.where('title IS NULL OR title NOT ILIKE ?', pattern) : scope.where('title ILIKE ?', pattern)
  end

  # Solo el grupo positivo sube el liston. El negado (!GESTION) sigue siendo el corpus
  # general con un recorte, no un corpus estrecho, asi que conserva el umbral de siempre.
  def group_threshold(group)
    return nil if group.blank? || group.start_with?('!')

    GROUP_SIMILARITY_THRESHOLD
  end

  def perform_pgvector(question, source_type, group = nil)
    items = search_items(grouped_items(source_type, group), threshold: group_threshold(group))
    return false if items.nil?

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
    send_reply("#{with_branch_tag(reply_text)}\n\n_#{source_tag}_")
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

    items = search_items(@account.knowledge_items.where(knowledge_source_id: source.id))
    return false if items.nil?

    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en Google Doc '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
                   .join("\n\n")
                   .truncate(kbase_setting('max_context_chars'))

    reply_text = generate_contextual_reply(question, context)
    return false if reply_text.blank?

    send_reply("#{with_branch_tag(reply_text)}\n\n_#{source.name}_")
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
    send_reply("#{with_branch_tag(reply_text)}\n\n_#{source.name}_")
    true
  end

  def perform_sheet_faq(question, source)
    items = search_items(@account.knowledge_items.where(knowledge_source_id: source.id))
    return false if items.nil?

    if items.empty?
      Rails.logger.info "[KBase] ⚠️ Sin resultados en hoja FAQ '#{source.name}'"
      return false
    end

    context = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
                   .join("\n\n")
                   .truncate(kbase_setting('max_context_chars'))
    reply_text = generate_contextual_reply(question, context)
    return false if reply_text.blank?

    send_reply("#{with_branch_tag(reply_text)}\n\n_#{source.name}_")
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
    system_prompt = [
      header,
      ("Objetivo de la conversación: #{objective}" if objective.present?),
      branch_scope_rule.presence
    ].compact_blank.join("\n\n")

    user_prompt = <<~USER.strip
      El cliente #{first_name} preguntó: "#{question.truncate(300)}"

      Información relevante:
      #{context}

      Respondé usando esa información de forma completa y útil. Tono natural y conversacional.
      No uses prefijos como "Asesor:" ni comillas al inicio o final.

      FIDELIDAD A LA FUENTE (regla dura): la información de arriba se recuperó por
      parecido semántico, así que puede tratar de un tema vecino pero distinto al que
      preguntó el cliente. Nunca la adaptes para que encaje: no sustituyas el sujeto de
      un procedimiento por el de la pregunta (si la fuente explica cómo cambiar el
      vendedor y preguntaron por el precio, NO escribas "para cambiar el precio" sobre
      los pasos del vendedor). Los nombres de permisos, parámetros, campos y menús se
      citan textualmente como aparecen en la fuente.

      Si la fuente no cubre exactamente lo que preguntaron, decilo de frente: explicá
      brevemente qué sí cubre la documentación, aclará que no tenés el procedimiento
      exacto para su caso y ofrecé pasarlo con un asesor. Una respuesta honesta que no
      resuelve es mejor que una inventada que parece resolver.
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

    result = search_discourse(@search_texts, source.config)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ Sin resultados en Discourse → sin respuesta'
      return false
    end

    history = load_history
    answer  = ask_openai_with_history(question, result[:context], history)
    return false if answer.blank?

    answer         = strip_echoed_sources(answer)
    answer, footer = split_declared_source(answer, result[:sources], question)
    return false if answer.blank?

    save_history(history, question, answer)
    answer = with_branch_tag(answer)
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

    result = search_discourse(@search_texts, hook.settings)
    if result[:context].blank?
      Rails.logger.info '[KBase] ⚠️ @discourse: sin resultados → sin respuesta'
      return false
    end

    history = load_history
    answer  = ask_openai_with_history(question, result[:context], history)
    return false if answer.blank?

    answer         = strip_echoed_sources(answer)
    answer, footer = split_declared_source(answer, result[:sources], question)
    return false if answer.blank?

    save_history(history, question, answer)
    answer = with_branch_tag(answer)
    send_reply(footer.present? ? "#{answer}#{footer}" : answer)
    true
  end

  # Llama al endpoint de Discourse AI semantic search y obtiene el contenido completo
  # Metadatos de los posts que devuelve UNA consulta, sin bajar el contenido: así los
  # resultados de varias consultas se fusionan primero y el fetch —con su rate limit de
  # 1.5s entre llamadas— se paga una sola vez, sobre la lista ya deduplicada y recortada.
  def discourse_hits(query, config)
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

    data      = JSON.parse(http.request(request).body)
    posts     = data['posts'] || []
    topic_map = (data['topics'] || []).index_by { |t| t['id'] }

    Rails.logger.info "[KBase] 📚 #{posts.size} resultado(s) en Discourse semantic-search"

    posts.filter_map do |post|
      topic = topic_map[post['topic_id']]
      next unless topic

      {
        post_id: post['id'],
        title: topic['title'].to_s.strip,
        url: "#{url}/t/#{topic['slug']}/#{topic['id']}",
        blurb: post['blurb'].to_s.strip
      }
    end
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error en Discourse search: #{e.message}"
    []
  end

  # Recibe TODAS las consultas del turno (ver search_queries) y devuelve un solo contexto
  # con los resultados de todas ellas, entrelazados y sin repetidos.
  def search_discourse(queries, config)
    url      = config['url'].to_s.chomp('/')
    api_key  = config['api_key'].to_s
    username = config['username'].presence || 'system'

    hits = interleave(Array(queries).map { |query| discourse_hits(query, config) })
           .uniq { |hit| hit[:post_id] }

    sources = []
    context = hits.first(MAX_RESULTS).each_with_index.filter_map do |hit, idx|
      sleep(1.5) if idx.positive? # evitar rate limit entre fetches consecutivos

      content = fetch_post_content(hit[:post_id], url, api_key, username).presence || hit[:blurb]
      next if content.blank?

      Rails.logger.info "[KBase]   📄 post##{hit[:post_id]} — #{hit[:title].truncate(50)} (#{content.length} chars)"

      # El índice se numera sobre `sources`, no sobre la posición del hit: los posts sin
      # contenido se descartan, así que las dos se desincronizan y el marcador [FUENTE n]
      # apuntaría al vecino.
      sources << { title: hit[:title], url: hit[:url] }
      "[FUENTE #{sources.size}] #{hit[:title]}\n#{content}"
    end.join("\n\n")

    { context: context, sources: sources }
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error armando contexto de Discourse: #{e.message}"
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

    # temperature 0: con 0.5 el modelo ignoraba la regla de fidelidad en ~1 de cada 3
    # respuestas y volvía a servir el procedimiento de una fuente vecina como si fuera
    # el que le preguntaron. Aquí no queremos redacción creativa, queremos que se
    # ciña a la fuente.
    call_openai_simple(build_messages(question, context, history), max_tokens: 600, temperature: 0.0)
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
                              .gsub(KnowledgeBase::Directives::CANNED_RE, '')
                              .gsub(/@buscar_art[ií]culo\b/i, '')
                              .gsub(/@discourse\b/i, '')
                              .strip
                              .presence
  end

  # El clasificador (@ruta) ya decidió de qué trata el turno, y con esa decisión se eligió
  # la fuente. Pero el prompt del agente lleva las instrucciones de TODAS sus ramas, así que
  # el modelo las ve todas y vuelve a decidir por su cuenta — a veces contradiciendo al
  # router. Medido: con la rama comercial_info ya resuelta y la tabla de precios delante,
  # "quiero cotizar 20 licencias" se contestaba con el guion de la rama de gestión (pedir
  # correo y razón social) en vez de dar la cifra que tenía enfrente.
  #
  # Se le nombra la rama con la descripción que escribió el autor en su propia línea @ruta:
  # el motor no sabe cómo se llaman las secciones del prompt, pero el autor sí las describió
  # ahí, y esas palabras son las que le permiten al modelo emparejarlas.
  #
  # Va SIEMPRE al final del system prompt, después del objetivo. Medido: colgada del prompt
  # y con el objetivo detrás, el modelo daba ya la cifra correcta pero seguía pidiendo datos
  # y cerrando con la etiqueta de gestión, porque el objetivo termina diciéndole que él
  # distinga si es información o gestión — justo lo que esta regla le prohíbe volver a hacer.
  def branch_scope_rule
    return '' if @route.blank?

    label = [@route.name, @route.description].compact_blank.join(' — ')
    <<~RULE.chomp
      RAMA YA DECIDIDA PARA ESTE TURNO: #{label}
      El sistema clasificó el mensaje en esa rama y la información que recibes es la de esa
      rama. De las instrucciones de arriba aplica únicamente las que correspondan a esa rama
      e ignora las de las otras. No vuelvas a clasificar el mensaje ni cambies de rama por tu
      cuenta.
    RULE
  end

  # FUENTE_USADA acopla el texto al link: antes el footer adivinaba a posteriori, por
  # overlap de palabras, cuál de las fuentes había usado el modelo. Ahora lo declara él.
  #
  # La regla de fidelidad se queda corta a propósito. Un agente con complementary_prompt
  # ya suele traer la suya (regla de evidencia, no diagnosticar, nombres exactos) mucho
  # más detallada, y apilar texto sobre un prompt ya largo no hace que se cumpla: medido
  # sobre el mismo caso, gpt-4o-mini ignoraba ambas versiones por igual y gpt-4o las
  # cumplía sin ayuda. Esto es el mínimo que el mecanismo necesita, no un intento de
  # corregir al modelo a fuerza de instrucciones.
  SOURCE_FIDELITY_RULE = <<~RULE

    SOBRE ESAS FUENTES:
    - Llegan por parecido semántico, así que la mejor puede tratar de un tema vecino
      pero distinto al que preguntaron. No adaptes una fuente para que encaje: no
      sustituyas el sujeto de un procedimiento por el de la pregunta.
    - Empezá SIEMPRE tu respuesta con una línea "FUENTE_USADA: n", donde n es el número
      de la [FUENTE n] en la que te basaste. Si no te basaste en ninguna, escribí
      "FUENTE_USADA: 0". Esa línea se elimina antes de mostrarla al cliente.
  RULE

  # "FUENTE_USADA: 2" — la línea que el modelo antepone para declarar en qué fuente se basó.
  USED_SOURCE_RE = /\A\s*FUENTE_USADA:\s*(\d+)\s*\n?/i

  def build_messages(question, context, history)
    system_content = agent_system_prompt || <<~PROMPT.strip
      Eres un agente de soporte de #{@account.name}. Respondé preguntas
      de forma conversacional y concisa, como lo haría un experto de soporte.
      - Usá el contenido del foro como referencia, respondé con tus propias palabras.
      - Si necesitás más información, hacé UNA pregunta de seguimiento.
      - Respondé en el mismo idioma que el cliente.
      - No menciones que consultaste un foro o base de conocimiento.
    PROMPT

    system_content += "\n\nContenido relevante del foro:\n#{context}#{SOURCE_FIDELITY_RULE}" if context.present?
    system_content += "\n\n#{branch_scope_rule}" if branch_scope_rule.present?

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
  # el que resuelve split_declared_source.
  def strip_echoed_sources(text)
    text.split("\n").reject do |line|
      line.match?(/^\s*📚/) ||
        line.match?(/^\s*fuentes relacionadas:?\s*$/i) ||
        line.match?(%r{^\s*[-*]?\s*https?://\S+\s*$}i)
    end.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

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

  # Separa la declaración "FUENTE_USADA: n" del texto para el cliente y devuelve el
  # footer de esa misma fuente — la que el modelo dice haber usado, no la que se parezca
  # más. Si declaró 0, el link se ofrece igual pero como "tema relacionado": citarlo bajo
  # "Más información" prometería una respuesta que el texto no da.
  #
  # Si el modelo no puso el marcador (se lo saltó), caemos al overlap de palabras de
  # siempre en vez de quedarnos sin fuente.
  def split_declared_source(answer, sources, question)
    match = answer.to_s.match(USED_SOURCE_RE)
    clean = match ? answer.sub(USED_SOURCE_RE, '').strip : answer.to_s.strip

    # Sin marcador no sabemos en que se baso: se trata igual que un FUENTE_USADA: 0. Antes
    # se adivinaba por overlap y se publicaba como "Mas informacion", que afirma una
    # procedencia que no consta -- asi acabo citando "Error manejador de licencias offline"
    # en una respuesta sobre facturacion, por dos palabras en comun. El modelo omite el
    # marcador en cerca de la mitad de los turnos, asi que esta rama no es un caso raro.
    idx = match ? match[1].to_i : 0

    # FUENTE_USADA: 0 — el modelo dice que ninguna fuente responde la pregunta. El link
    # se ofrece igual, pero con otra etiqueta: "Más información" promete la respuesta y
    # aquí no la hay, así que el hilo más cercano se cita como material relacionado.
    if idx.zero? || idx > sources.size
      Rails.logger.info "[KBase] 🔗 #{match ? "FUENTE_USADA: #{idx}" : 'sin marcador'} → " \
                        'no consta que se haya usado una fuente, se cita la más cercana como relacionada'
      return [clean, ''] if sources.empty?

      related = closest_source(sources, question, clean)
      return [clean, ''] if related.blank?

      return [clean, "\n\n🔎 Tema relacionado que quizá te sirva: #{related[:url]}"]
    end

    source = sources[idx - 1]
    Rails.logger.info "[KBase] 🔗 Fuente declarada por el modelo: [#{idx}] '#{source[:title].truncate(40)}'"
    [clean, "\n\n📚 Más información: #{source[:url]}"]
  end

  # La más parecida por overlap. No se le exige un mínimo alto: aquí ya la estamos
  # etiquetando como "relacionada", no como la fuente de la respuesta. Sin ningún término
  # en común no se cita nada.
  def closest_source(sources, question, answer)
    words = significant_words("#{question} #{answer}")
    best  = sources.max_by { |source| (words & significant_words(source[:title])).size }
    return nil unless words.intersect?(significant_words(best[:title]))

    best
  end

  # ==============================================================================
  # Envío de respuesta
  # ==============================================================================

  # La etiqueta final (#gestion, #soporte2...) no es adorno: es lo que dispara las
  # automatizaciones, que filtran por el contenido del mensaje. Si falta, la automatizacion
  # simplemente no corre, y en silencio.
  #
  # Medido sobre 20 turnos: el modelo la omitia en las respuestas que no resuelven nada
  # -- pedir una aclaracion, ir reuniendo datos --, 4 de cada 5 de esos casos. Reforzar la
  # regla en [ETIQUETAS] corrigio eso en la corrida de verificacion (6 de 6, y el modelo
  # eligiendo el grado de soporte por su cuenta), asi que esto NO sustituye al prompt: es
  # la red para cuando se le vuelva a pasar.
  #
  # Solo se AGREGA cuando falta. La que puso el modelo se respeta siempre, porque el la
  # eligio viendo el mensaje y el motor solo conoce la rama -- por eso en soporte conviene
  # declarar el grado mas conservador en la linea @ruta.
  ANY_TAG_RE = /#[a-z0-9_]{3,}/i

  def with_branch_tag(text)
    tag = @route&.hashtag
    return text if tag.blank? || text.blank?

    found = text.scan(ANY_TAG_RE)
    if found.any?
      Rails.logger.info "[KBase] 🏷️ #{found.size} etiqueta(s) del modelo: #{found.join(' ')}" if found.size > 1
      return text
    end

    Rails.logger.info "[KBase] 🏷️ Sin etiqueta → se repone la de la rama '#{@route.name}': #{tag}"
    "#{text.rstrip}\n\n#{tag}"
  end

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

  # El selector "Modelo de IA" del hook tracking_bot es por inbox y EngineConfig es su
  # única fuente — su cabecera avisa que todo punto que llame a OpenAI desde el motor de
  # Seguimientos debe resolver el modelo por ahí. Este archivo no lo hacía: mandaba
  # gpt-4o-mini por ENV, así que elegir GPT-4o en la pantalla de integraciones no tenía
  # ningún efecto sobre las respuestas de la base de conocimiento. Configuración fantasma,
  # la misma que EngineConfig vino a eliminar.
  def resolved_model
    return ContactTrackings::EngineConfig.model_for(@inbox) if @inbox.present?

    ENV.fetch('OPENAI_GPT_MODEL', ContactTrackings::EngineConfig::DEFAULT_MODEL)
  end

  def call_openai_simple(messages, max_tokens: 600, temperature: 0.5)
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
      model: resolved_model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
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
