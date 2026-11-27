# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia F1 — LOS GRUPOS DE PREDEFINIDAS QUE SE ELIGEN EN LA FICHA
# ================================================================================
# Lo que va en @buscar_predefinidas(GRUPO). El motor entiende dos formas
# (KnowledgeBase::CannedGroup):
#   · una CATEGORÍA fija: General, Ficha u Objeción          → source: 'kind'
#     (proyecto@predefinidas_que_contestan; solo si la cuenta ya usa alguna que no sea
#     General: con todas en General, «General» sería todo)
#   · el PRINCIPIO del nombre                                  → source: 'prefix'
# Un prefijo que se llama como una categoría fija no se ofrece: el motor buscaría la
# categoría.
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
    (kinds + prefixes).sort_by { |g| [-g[:count], g[:label]] }
  end

  private

  def rows
    @rows ||= @account.canned_responses.pluck(:id, :short_code, :kind)
  end

  def ready_ids
    @ready_ids ||= KnowledgeItem.where(account_id: @account.id, source_type: 'canned_response')
                                .where.not(embedding: nil).distinct.pluck(:source_id).to_set
  end

  KIND_LABELS = { 'general' => 'General', 'ficha' => 'Ficha', 'objecion' => 'Objeción' }.freeze

  def kinds
    por_kind = rows.group_by { |r| r[2].presence || 'general' }
    return [] if por_kind.keys == ['general']

    por_kind.filter_map { |kind, grupo| (label = KIND_LABELS[kind]) && group(label, grupo, 'kind') }
  end

  def prefixes
    rows.group_by { |r| prefix(r[1]) }.filter_map do |prefijo, grupo|
      next if prefijo.nil? || KnowledgeBase::CannedGroup.kind_named(prefijo)

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
