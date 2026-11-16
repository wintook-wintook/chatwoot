# frozen_string_literal: true

# Motor 2.0 — buscar en las fuentes que la ficha marcó («Qué sabe»). Usa tal cual lo del 1.0:
# las predefinidas con AiFollowUps::KnowledgeSearch (separa las instrucciones internas) y el
# resto por parecido sobre knowledge_items de esa fuente (artículos, documentos, hojas, foro,
# CONTPAQi), igual que KnowledgeBaseResponseService.
#
#   Motor2::Search.new(account, sources).call('¿cuánto cuesta Derecho?', only: 'Precios')
#   → [{ fuente: 'Precios', resultados: [...] }]
class Motor2::Search < Cases::Ai::BaseService
  CANNED = 'canned_response'
  LIMIT = 4
  THRESHOLD = 0.2
  MAX_CHARS = 1500

  Source = Struct.new(:key, :name, :kind, :knowledge_source_ids, keyword_init: true)

  def initialize(account, keys)
    super(account: account)
    @keys = keys
  end

  # Las fuentes de la ficha que existen y están activas.
  def sources
    @sources ||= @keys.filter_map { |key| resolve(key) }
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
    source && Source.new(key: key, name: source.name, kind: type, knowledge_source_ids: [source.id])
  end

  def canned = @canned ||= AiFollowUps::KnowledgeSearch.new(account: @account)

  def search(source, question)
    return Array(canned.canned(question)[:results]) if source.kind == 'canned'

    semantic(source, question)
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
