# frozen_string_literal: true

# Motor 2.0 — buscar en el Catálogo de la empresa, como search_catalog de Dali: por
# palabras (sirve para catálogos chicos; el buscador para bases grandes viene después). Viene del
# agente listo de antes (ReadyAgents::CatalogSearch).
class Motor2::CatalogSearch
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

  # Lo que hay en el Catálogo, por categoría (para «¿qué venden?»).
  OVERVIEW_LIMIT = 30

  def overview
    @account.catalog_items.where(active: true).order(:category, :name).limit(OVERVIEW_LIMIT).map { |item| row(item) }
  end

  # El producto que nombró (para cotizar o agendar): primero el que lo trae en su nombre; si no, el mejor por palabras.
  # Así «peinado» es «Peinado / ondas» y no «Paquete novia» (que lo dice en su descripción).
  def item(name)
    stems = stems(name)
    return nil if stems.empty?

    active = @account.catalog_items.where(active: true)
    by_name = active.limit(SCAN).select { |i| stems.all? { |s| GlobalSearch.normalize(i.name).include?(s) } }
    return by_name.min_by { |i| i.name.length } if by_name.any?

    best = Array(call(name)[:results]).first
    best && active.find_by(name: best[:nombre])
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
