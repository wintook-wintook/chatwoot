# frozen_string_literal: true

# Motor 2.0 — buscar en las fuentes del agente («Qué sabe»). Las respuestas predefinidas van
# siempre (no se marcan); las demás, las que marcó la ficha. Usa tal cual lo del 1.0:
# las predefinidas con AiFollowUps::KnowledgeSearch (separa las instrucciones internas) y el
# resto por parecido sobre knowledge_items de esa fuente (artículos, documentos, hojas, foro,
# CONTPAQi), igual que KnowledgeBaseResponseService. Una hoja en modo «Datos» se busca EXACTO en sus
# filas con SheetQueryService (el código calcula, sin inventar números), como en el 1.0. CONTPAQi no
# guarda nada en la plataforma: se le pregunta en vivo a su Agente de Servicio (Contpaq::ServiceAgent,
# el mismo cliente del 1.0, con el mismo identificador del contacto y la memoria por conversación). El
# foro (discourse) tampoco: se consulta en vivo con Motor2::ForumSearch.
#
# Orden de consulta (en cascada): en el orden que dejó la empresa en «Qué sabe» (con ↑ ↓) o, si no lo
# ordenó, predefinidas → Catálogo → hojas y artículos → documentos → foro → CONTPAQi. Antes de una fuente
# lenta (foro, CONTPAQi) se revisa si lo encontrado ya lo contesta (Motor2::ResultCheck): si sí, no se
# consulta (se ahorra tiempo y costo). Con «fuente», solo esa.
#
#   Motor2::Search.new(account, sources).call('¿cuánto cuesta Derecho?', only: 'Precios')
#   → [{ fuente: 'Precios', resultados: [...] }]
class Motor2::Search < Cases::Ai::BaseService
  CANNED = 'canned_response'
  # En las fuentes de la ficha, «sin predefinidas»: un agente que no debe ver las de la cuenta (p. ej. una demo de otro
  # giro en la misma cuenta). Se pone a mano (no sale en la pantalla) y se conserva al guardar el agente.
  NO_CANNED = '-canned_response'
  LIMIT = 4
  THRESHOLD = 0.2
  MAX_CHARS = 1500

  Source = Struct.new(:key, :name, :kind, :knowledge_source_ids, :record, keyword_init: true)
  # Sin orden de la empresa: de lo propio y rápido a lo externo y lento.
  PRIORITY = { 'canned' => 0, 'catalog' => 1, 'google_sheet' => 2, 'article' => 2, 'discourse' => 8, 'contpaq_support' => 9 }.freeze
  SLOW = %w[discourse contpaq_support].freeze

  # Lo que concluyó la cascada al detenerse (para no revisarlo otra vez: Motor2::Skills::SupportFlow#judge).
  attr_reader :last_check

  # customer_words: lo que escribió el cliente (CONTPAQi lo recibe tal cual, como en el 1.0).
  def initialize(account, keys, conversation: nil, customer_words: nil)
    super(account: account)
    @keys = keys
    @conversation = conversation
    @customer_words = customer_words.to_s.strip.presence
  end

  # Lo que escogió la búsqueda nueva de predefinidas (nil si no corrió), para la traza.
  def selection = @canned&.last_selection

  # Las predefinidas (siempre) y las fuentes de la ficha que existen y están activas.
  def sources
    @sources ||= ordered_keys.filter_map { |key| resolve(key) }
  end

  # Con las predefinidas en la lista, la empresa ya las ordenó; si no, por PRIORITY (las de antes).
  def ordered_keys
    keys = Array(@keys).map(&:to_s)
    return (keys - [NO_CANNED, CANNED]).uniq if keys.include?(NO_CANNED)
    return keys.uniq if keys.include?(CANNED)

    ([CANNED] + keys).uniq.each_with_index.sort_by { |key, i| [PRIORITY.fetch(key.split(':').first, 5), i] }.map(&:first)
  end

  def names = sources.map(&:name)

  def call(question, only: nil)
    @last_check = nil
    targets = only.present? ? sources.select { |s| s.name.casecmp?(only.to_s) } : []
    return targets.map { |source| found(source, question) } if targets.any?

    cascade(question)
  end

  private

  def found(source, question) = { fuente: source.name, tipo: source.kind, resultados: search(source, question) }

  # Una tras otra; antes de una lenta, si lo encontrado ya lo contesta, se detiene.
  def cascade(question)
    sources.each_with_index.with_object([]) do |(source, i), out|
      break out if SLOW.include?(source.kind) && answered?(question, out, sources[i..])

      out << found(source, question)
    end
  end

  # Lo que falta consultar va con lo que tiene (otro sistema, otro producto): si no dijo de cuál habla, se sigue.
  def answered?(question, out, rest)
    hits = out.reject { |f| f[:resultados].empty? }
    return false if hits.empty?

    pending = rest.map { |s| [s.name, about(s)].compact_blank.join(': ') }
    @last_check = Motor2::ResultCheck.new(account: @account).call(question: @customer_words || question, found: hits, pending: pending)
    @last_check.to_h['tipo'] == 'exacta'
  end

  # Qué hay en esa fuente (Motor2::SourceMap: lo que dice la empresa o lo que se dedujo).
  def about(source) = Motor2::SourceMap.new(@account).entries([source.key]).find { |e| e[:key] == source.key }&.dig(:about).to_s.first(200)

  def resolve(key)
    return Source.new(key: key, name: 'Respuestas predefinidas', kind: 'canned') if key == CANNED && canned.canned_available?
    return catalog_source(key) if key == Motor2::SourceMap::CATALOG

    return articles_source(key) if key == 'article'

    type, id = key.to_s.split(':', 2)
    source = @account.knowledge_sources.active.find_by(id: id, source_type: type) if id
    source && Source.new(key: key, name: source.name, kind: type, knowledge_source_ids: [source.id], record: source)
  end

  def canned = @canned ||= AiFollowUps::KnowledgeSearch.new(account: @account, conversation: @conversation)

  def search(source, question)
    return Array(canned.canned(question)[:results]) if source.kind == 'canned'
    return catalog_results(question) if source.kind == 'catalog'
    return exact_sheet(source, question) if data_sheet?(source)
    return contpaq(source, question) if source.kind == 'contpaq_support'
    return forum(source, question) if source.kind == 'discourse'

    semantic(source, question)
  end

  def articles_source(key)
    ids = @account.knowledge_sources.active.where(source_type: 'article').ids
    ids.any? ? Source.new(key: key, name: 'Artículos de ayuda', kind: 'article', knowledge_source_ids: ids) : nil
  end

  # El Catálogo de productos (catalog_items) como una fuente más: por palabras, con su precio.
  def catalog_source(key)
    return nil unless @account.catalog_items.exists?(active: true)

    Source.new(key: key, name: Motor2::SourceMap::CATALOG_NAME, kind: 'catalog')
  end

  # «¿Qué venden?», «¿qué servicios tienen?», «lista de precios»: sin un producto en la pregunta, lo que hay en el Catálogo.
  OVERVIEW = /\bqu[eé]\s+(vend|ofrec|tien|hac|manej)|\bservicios\b|\bproductos\b|cat[aá]logo|lista\s+de\s+precios|\bmen[uú]\b|\bprecios\b/i

  def catalog_results(question)
    search = Motor2::CatalogSearch.new(@account)
    rows = Array(search.call(question)[:results])
    rows = search.overview if rows.empty? && question.to_s.match?(OVERVIEW)
    rows.map do |row|
      price = row[:precio] ? "Precio: $#{money(row[:precio])}" : 'Sin precio'
      { titulo: row[:nombre], informacion: [price, row[:unidad] && "por #{row[:unidad]}", row[:descripcion]].compact_blank.join('. ') }
    end
  end

  def money(value) = ActiveSupport::NumberHelper.number_to_delimited(value.round(2).to_s.delete_suffix('.0'))

  def data_sheet?(source)
    source.kind == 'google_sheet' && source.record&.config.to_h&.dig('sheet_mode') == 'data'
  end

  CONTPAQ_NOTE = 'Respuesta del Agente de Servicio CONTPAQi: dásela completa, con sus pasos y datos tal cual (sin cambiarlos ' \
                 'ni agregar otros); si trae liga de documentación, inclúyela.'

  # En vivo: CONTPAQi contesta ya redactado (y con su documentación). En el chat de prueba no hay contacto:
  # se pregunta con un identificador de prueba de la cuenta y sin memoria.
  def contpaq(source, question)
    asked = (@customer_words || question).to_s.first(1000) # con las palabras del cliente: así contesta mejor
    result = Contpaq::ServiceAgent.new(source.record).answer(question: asked, user_id: contpaq_user,
                                                             conversation_id: contpaq_conversation)
    return [] unless result.ok?

    url = Array(result.sources).find { |s| s[:url].present? }&.dig(:url)
    [{ titulo: source.name, informacion: "#{CONTPAQ_NOTE}\n#{result.answer}".first(4000), liga: url }.compact]
  rescue StandardError => e
    Rails.logger.warn("[Motor2::Search] CONTPAQi: #{e.class}: #{e.message}")
    []
  end

  # El foro en vivo; la búsqueda normal le pide a la IA 1–3 búsquedas cortas.
  def forum(source, question)
    ask = lambda do |messages|
      chat(system: messages.find { |m| m[:role] == 'system' }&.dig(:content).to_s,
           user: messages.find { |m| m[:role] == 'user' }&.dig(:content).to_s, temperature: 0, max_tokens: 60)
    end
    Motor2::ForumSearch.new(source.record, ask: ask).call(question.to_s.first(500))
  end

  def contpaq_user
    Contpaq::UserIdBuilder.new(@conversation&.contact, @account).build ||
      "prueba_#{@account.id.to_s.rjust(Contpaq::UserIdBuilder::ACCOUNT_WIDTH, '0')}@#{Contpaq::UserIdBuilder::DOMAIN}"
  end

  def contpaq_conversation = @conversation && "acct-#{@account.id}-conv-#{@conversation.display_id}"

  # El resultado lo calcula Ruby sobre las filas (exacto): el modelo solo lo redacta.
  def exact_sheet(source, question)
    result = SheetQueryService.new(source.record, question, @account).perform
    result.present? ? [{ titulo: source.name, informacion: "Resultado exacto de la hoja: #{result}".first(MAX_CHARS) }] : []
  end

  def semantic(source, question)
    scope = KnowledgeItem.where(account_id: @account.id, knowledge_source_id: source.knowledge_source_ids)
                         .where.not(embedding: nil)
    return [] unless scope.exists?

    vector = embed(question.to_s.first(500))
    return [] if vector.blank?

    scope.search_by_embedding(vector, limit: LIMIT, threshold: THRESHOLD).map do |item|
      { titulo: item.title.to_s.first(200), informacion: item.content.to_s.first(MAX_CHARS) }.compact_blank
    end
  end
end
