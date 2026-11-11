# frozen_string_literal: true

# Agentes listos — buscar en el Catálogo de la empresa, como search_catalog de Dali: por
# palabras (sirve para catálogos chicos; el buscador para bases grandes viene después).
class ReadyAgents::CatalogSearch
  LIMIT = 5
  SCAN = 2000

  def initialize(account)
    @account = account
  end

  def call(query)
    stems = stems(query)
    return { results: [] } if stems.empty?

    found = @account.catalog_items.where(active: true).limit(SCAN).filter_map do |item|
      hits = stems.count { |s| GlobalSearch.normalize([item.name, item.sku, item.description].join(' ')).include?(s) }
      [item, hits] if hits.positive?
    end
    { results: found.sort_by { |(item, hits)| [-hits, item.name] }.first(LIMIT).map { |(item, _)| row(item) } }
  end

  private

  def stems(query)
    words = GlobalSearch.normalize(query).split.select { |w| w.length > 2 }
    words.map { |w| w.length > 4 ? w.sub(/(es|s)\z/, '') : w }
  end

  def row(item)
    { nombre: item.name, precio: item.price&.to_f, unidad: item.unit, descripcion: item.description.to_s.truncate(200) }.compact
  end
end
