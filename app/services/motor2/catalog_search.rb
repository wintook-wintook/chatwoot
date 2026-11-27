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
    by_name = named(stems)
    return by_name.min_by { |i| i.name.length } if by_name.any?

    best = Array(call(name)[:results]).first
    best && active.find_by(name: best[:nombre])
  end

  # Lo que el cliente dijo que en el Catálogo tiene varias opciones («otro corte» → Corte de dama / Corte de caballero),
  # si no dijo cuál: { 'corte' => [items] }. La palabra que comparten es la primera de su nombre.
  def ambiguous_in(text)
    words = GlobalSearch.normalize(text).split
    heads = @account.catalog_items.where(active: true).limit(SCAN).group_by { |i| GlobalSearch.normalize(i.name).split.first }
    heads.select do |head, items|
      items.size > 1 && words.any? { |w| w.start_with?(head.to_s[0, 5]) } && items.none? { |i| said_rest?(i, words) }
    end
  end

  # Dijo lo que distingue a ese producto («dama», «caballero»).
  def said_rest?(item, words)
    rest = GlobalSearch.normalize(item.name).split.drop(1).select { |w| w.length > 2 }
    rest.any? { |w| words.include?(w) }
  end

  # Solo si lo nombró sin duda: uno solo trae en su nombre todas sus palabras («caballero» → Corte de caballero).
  def named_item(text)
    stems = stems(text)
    found = stems.any? ? named(stems) : []
    found.one? ? found.first : nil
  end

  private

  def named(stems)
    @account.catalog_items.where(active: true).limit(SCAN).select { |i| stems.all? { |s| GlobalSearch.normalize(i.name).include?(s) } }
  end

  def stems(query)
    words = GlobalSearch.normalize(query).split.select { |w| w.length > 2 }
    words.map { |w| w.length > 4 ? w.sub(/(es|s)\z/, '') : w }
  end

  def row(item)
    { nombre: item.name, precio: item.price&.to_f, unidad: item.unit, descripcion: item.description.to_s.truncate(200) }.compact
  end
end
