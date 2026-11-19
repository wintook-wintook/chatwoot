# frozen_string_literal: true

# Motor 2.0 — buscar en las fuentes del agente («Qué sabe»). Las respuestas predefinidas van
# siempre (no se marcan); las demás, las que marcó la ficha. Usa tal cual lo del 1.0:
# las predefinidas con AiFollowUps::KnowledgeSearch (separa las instrucciones internas) y el
# resto por parecido sobre knowledge_items de esa fuente (artículos, documentos, hojas, foro,
# CONTPAQi), igual que KnowledgeBaseResponseService. Una hoja en modo «Datos» se busca EXACTO en sus
# filas con SheetQueryService (el código calcula, sin inventar números), como en el 1.0.
#
#   Motor2::Search.new(account, sources).call('¿cuánto cuesta Derecho?', only: 'Precios')
#   → [{ fuente: 'Precios', resultados: [...] }]
class Motor2::Search < Cases::Ai::BaseService
  CANNED = 'canned_response'
  LIMIT = 4
  THRESHOLD = 0.2
  MAX_CHARS = 1500

  Source = Struct.new(:key, :name, :kind, :knowledge_source_ids, :record, keyword_init: true)

  def initialize(account, keys, conversation: nil)
    super(account: account)
    @keys = keys
    @conversation = conversation
  end

  # Lo que escogió la búsqueda nueva de predefinidas (nil si no corrió), para la traza.
  def selection = @canned&.last_selection

  # Las predefinidas (siempre) y las fuentes de la ficha que existen y están activas.
  def sources
    @sources ||= ([CANNED] + @keys).uniq.filter_map { |key| resolve(key) }
  end

  def names = sources.map(&:name)

  def call(question, only: nil)
    targets = only.present? ? sources.select { |s| s.name.casecmp?(only.to_s) } : sources
    targets = sources if targets.empty?
    targets.map { |source| { fuente: source.name, tipo: source.kind, resultados: search(source, question) } }
  end

  private

  def resolve(key)
    return Source.new(key: key, name: 'Respuestas predefinidas', kind: 'canned') if key == CANNED && canned.canned_available?

    if key == 'article'
      ids = @account.knowledge_sources.active.where(source_type: 'article').ids
      return ids.any? ? Source.new(key: key, name: 'Artículos de ayuda', kind: 'article', knowledge_source_ids: ids) : nil
    end

    type, id = key.to_s.split(':', 2)
    source = @account.knowledge_sources.active.find_by(id: id, source_type: type) if id
    source && Source.new(key: key, name: source.name, kind: type, knowledge_source_ids: [source.id], record: source)
  end

  def canned = @canned ||= AiFollowUps::KnowledgeSearch.new(account: @account, conversation: @conversation)

  def search(source, question)
    return Array(canned.canned(question)[:results]) if source.kind == 'canned'
    return exact_sheet(source, question) if data_sheet?(source)

    semantic(source, question)
  end

  def data_sheet?(source)
    source.kind == 'google_sheet' && source.record&.config.to_h&.dig('sheet_mode') == 'data'
  end

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
