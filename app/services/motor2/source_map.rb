# frozen_string_literal: true

# Motor 2.0 — el mapa de las fuentes de un agente: qué hay en cada una, para que el agente sepa
# DÓNDE buscar cada cosa (y no busque en todas). Lo de cada fuente sale de su «¿Qué hay aquí?»
# (knowledge_sources.config['purpose'], que se escribe en Bases de conocimiento) o, si no lo tiene,
# de lo que tiene dentro, sin IA:
#   - respuestas predefinidas: sus categorías (General, Ficha, Objeción) con algunos nombres;
#   - hoja: sus columnas y cuántas filas (y si contesta datos exactos);
#   - documento y artículos: algunos títulos;
#   - foro y CONTPAQi: se consultan en vivo;
#   - Catálogo de productos (catalog_items): cuántos productos con precio y algunos nombres.
#
#   Motor2::SourceMap.new(account).entries(['canned_response', 'google_sheet:12'])
#   → [{ key:, name:, kind:, about:, purpose:, auto: }]
#   Motor2::SourceMap.new(account).available   → todas las de la cuenta (para el asistente)
class Motor2::SourceMap
  CANNED = 'canned_response'
  CATALOG = 'catalog'
  TYPES = %w[google_sheet google_doc discourse contpaq_support].freeze
  KIND_TITLES = { 'general' => 'General', 'ficha' => 'Fichas', 'objecion' => 'Objeciones' }.freeze
  SAMPLE = 6
  MAX_PURPOSE = 300

  def initialize(account)
    @account = account
  end

  # Las fuentes que la cuenta le puede dar a un agente (las predefinidas primero).
  def available
    keys = [CANNED]
    keys << CATALOG if catalog_items.exists?
    keys << 'article' if @account.knowledge_sources.active.exists?(source_type: 'article')
    keys += @account.knowledge_sources.active.where(source_type: TYPES).order(:name).map { |s| "#{s.source_type}:#{s.id}" }
    entries(keys)
  end

  def entries(keys)
    ([CANNED] + Array(keys)).uniq.filter_map { |key| entry(key) }
  end

  # Las líneas «DÓNDE BUSCAR» para el prompt.
  def lines(keys)
    entries(keys).map { |e| "- #{e[:name]}: #{e[:about]}" }
  end

  def self.clean_purpose(text) = text.to_s.squish.first(MAX_PURPOSE)

  private

  def entry(key)
    return canned_entry if key == CANNED
    return articles_entry if key == 'article'
    return catalog_entry if key == CATALOG

    type, id = key.to_s.split(':', 2)
    source = @account.knowledge_sources.active.find_by(id: id, source_type: type) if id && TYPES.include?(type)
    source && build(key, source.name, type, source, auto_for(source))
  end

  def build(key, name, kind, source, auto)
    purpose = self.class.clean_purpose(source&.config.to_h&.dig('purpose')).presence
    { key: key, name: name, kind: kind, id: source&.id, purpose: purpose, auto: auto, about: purpose || auto,
      sheet_mode: (source.config.to_h['sheet_mode'] || 'faq' if kind == 'google_sheet') }.compact
  end

  def catalog_items = @account.catalog_items.where(active: true)

  # El Catálogo de productos no es una fuente de Bases de conocimiento: no tiene «¿Qué hay aquí?».
  def catalog_entry
    items = catalog_items
    return nil unless items.exists?

    about = "#{items.count} productos o servicios con su precio, como: #{sample(items.order(:name).limit(SAMPLE).pluck(:name))}"
    { key: CATALOG, name: CATALOG_NAME, kind: 'catalog', id: nil, purpose: nil, auto: about, about: about }
  end

  CATALOG_NAME = 'Catálogo de productos'

  def canned_entry
    responses = @account.canned_responses
    return nil unless responses.exists?

    source = @account.knowledge_sources.find_by(source_type: CANNED)
    return nil if source && source.status != 'active'

    parts = KIND_TITLES.filter_map do |kind, title|
      names = responses.where(kind: kind).order(:short_code).pluck(:short_code)
      "#{title} (#{names.size}): #{sample(names)}" if names.any?
    end
    build(CANNED, 'Respuestas predefinidas', 'canned', source, parts.join('; '))
  end

  def articles_entry
    source = @account.knowledge_sources.active.find_by(source_type: 'article')
    titles = KnowledgeItem.where(account_id: @account.id, source_type: 'article').distinct.limit(SAMPLE).pluck(:title)
    source && build('article', 'Artículos de ayuda', 'article', source, "artículos como: #{sample(titles)}")
  end

  def auto_for(source)
    case source.source_type
    when 'google_sheet' then sheet_text(source)
    when 'google_doc' then "documento con: #{sample(item_titles(source))}"
    else 'se consulta en vivo (preguntas y soluciones publicadas)'
    end
  end

  def sheet_text(source)
    columns = source.google_sheet_rows.order(:row_index).first&.data&.keys || []
    total = source.google_sheet_rows.count
    exact = source.config.to_h['sheet_mode'] == 'data' ? 'datos exactos por fila' : 'preguntas y respuestas'
    "tabla (#{exact}) con #{columns.first(8).join(' · ').presence || 'sin columnas'} (#{total} filas)"
  end

  def item_titles(source)
    KnowledgeItem.where(account_id: @account.id, knowledge_source_id: source.id).distinct.limit(SAMPLE).pluck(:title)
  end

  def sample(list)
    list = list.compact_blank.map { |t| t.to_s.squish.first(60) }
    return 'sin contenido todavía' if list.empty?

    shown = list.first(SAMPLE).join(', ')
    list.size > SAMPLE ? "#{shown}…" : shown
  end
end
