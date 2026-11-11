# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia F1 — LOS GRUPOS DE PREDEFINIDAS QUE SE ELIGEN EN LA FICHA
# ================================================================================
# Lo que va en @buscar_predefinidas(GRUPO). Desde R4 de respuestas predefinidas el motor
# entiende las dos formas (KnowledgeBase::CannedGroup):
#   · una CATEGORÍA (canned_response_categories)          → source: 'category'
#   · el PRINCIPIO del nombre de las que no tienen categoría → source: 'prefix'
# Un prefijo que choca con el nombre de una categoría no se ofrece: el motor buscaría
# la categoría.
#
# not_ready = cuántas del grupo no tienen vector: el agente no las encontraría.
# topics    = de qué tratan (los nombres sin el grupo), para describir la ruta.
# ================================================================================

class ContactTrackings::Ficha::CannedGroups
  MAX_TOPICS = 4

  def initialize(account)
    @account = account
  end

  def call
    (categories + prefixes).sort_by { |g| [-g[:count], g[:label]] }
  end

  private

  def rows
    @rows ||= @account.canned_responses.pluck(:id, :short_code, :category_id)
  end

  def ready_ids
    @ready_ids ||= KnowledgeItem.where(account_id: @account.id, source_type: 'canned_response')
                                .where.not(embedding: nil).distinct.pluck(:source_id).to_set
  end

  def category_names
    @category_names ||= @account.canned_response_categories.pluck(:id, :name).to_h
  end

  def categories
    rows.select { |r| r[2] }.group_by { |r| r[2] }.filter_map do |category_id, grupo|
      nombre = category_names[category_id]
      next if nombre.blank?

      group(nombre, grupo, 'category')
    end
  end

  def prefixes
    ocupados = category_names.values.map(&:downcase)
    rows.reject { |r| r[2] }.group_by { |r| prefix(r[1]) }.filter_map do |prefijo, grupo|
      next if prefijo.nil? || ocupados.include?(prefijo.downcase)

      group(prefijo, grupo, 'prefix')
    end
  end

  def group(label, grupo, source)
    { key: label, label: label, source: source, count: grupo.size,
      not_ready: grupo.count { |r| ready_ids.exclude?(r[0]) },
      topics: grupo.first(MAX_TOPICS).map { |r| topic(r[1], label) } }
  end

  # «PATITAS PRECIO CONSULTA» → «precio consulta». Solo la palabra completa: con
  # «Licenciaturas: servicio social» en el grupo Licenciatura quedaba «s: servicio social».
  def topic(code, label)
    texto = code.to_s.sub(/\A#{Regexp.escape(label)}(?![[:alnum:]])[\s_-]*/i, '')
    (texto.presence || code.to_s).tr('_-', '  ').squish.downcase
  end

  # Igual que InventoryService#group_prefix: una sola palabra no declara grupo.
  def prefix(code)
    parts = code.to_s.strip.split(/[\s\-_]+/)
    return nil if parts.size < 2

    parts.first.upcase.presence
  end
end
