# Productos y servicios › Parámetros — categorías, impuestos y unidades de la cuenta.
#
#   CatalogParameters.ensure!(account)              la primera vez: impuestos y unidades de fábrica, y lo que
#                                                   ya estaba escrito en los productos pasa a las listas
#   CatalogParameters.category_for(account, text)   «Refacciones › Frenos» (o «Refacciones > Frenos») → la
#                                                   subcategoría; la crea si no existe
#   CatalogParameters.unit_for(account, text)       «pza», «Pieza» → la unidad; la crea si no existe
module CatalogParameters
  PATH_SPLIT = /\s*(?:›|>)\s*/

  module_function

  def ensure!(account)
    return if account.tax_rates.exists?

    account.with_lock do
      next if account.tax_rates.exists?

      seed_taxes(account)
      seed_units(account) unless account.catalog_units.exists?
      link_items(account)
    end
  end

  def category_for(account, text)
    names = text.to_s.split(PATH_SPLIT).map { |n| n.squish.first(80) }.compact_blank.first(2)
    return if names.empty?

    parent = find_or_create_category(account, names.first, nil)
    names.size > 1 ? find_or_create_category(account, names.second, parent) : parent
  end

  def unit_for(account, text)
    value = text.to_s.squish
    return if value.blank?

    account.catalog_units.matching(value) ||
      account.catalog_units.create!(name: value.upcase_first.first(60), abbreviation: value.first(20))
  end

  def find_or_create_category(account, name, parent)
    account.catalog_categories.where(parent: parent).find_by('LOWER(name) = ?', name.downcase) ||
      account.catalog_categories.create!(name: name, parent: parent)
  end

  # La de por omisión es la que tiene el porcentaje que ya usaba la cuenta (Parámetros de ventas).
  def seed_taxes(account)
    current = CaseSetting.for_account(account).default_tax_percent.to_d
    rates = TaxRate::DEFAULTS.map do |name, percent, exempt|
      account.tax_rates.create!(name: name, percent: percent, exempt: exempt)
    end
    default = rates.find { |rate| !rate.exempt? && rate.percent == current } ||
              account.tax_rates.create!(name: "IVA #{current.to_s('F').delete_suffix('.0')} %", percent: current)
    default.update!(is_default: true)
    TaxRate::WITHHOLDING_DEFAULTS.each { |name, percent| account.tax_rates.create!(name: name, percent: percent, kind: :withholding) }
  end

  def seed_units(account)
    CatalogUnit::DEFAULTS.each do |name, abbreviation, sat_code|
      account.catalog_units.create!(name: name, abbreviation: abbreviation, sat_code: sat_code)
    end
  end

  # Lo que ya estaba escrito como texto en los productos (sin tocar su fecha de cambio).
  def link_items(account)
    account.catalog_items.where(catalog_category_id: nil).where.not(category: nil).find_each do |item|
      category = category_for(account, item.category)
      item.update_columns(catalog_category_id: category.id, category: category.path) if category # rubocop:disable Rails/SkipsModelValidations
    end
    account.catalog_items.where(catalog_unit_id: nil).where.not(unit: nil).find_each do |item|
      unit = unit_for(account, item.unit)
      item.update_columns(catalog_unit_id: unit.id, unit: unit.abbreviation) if unit # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
