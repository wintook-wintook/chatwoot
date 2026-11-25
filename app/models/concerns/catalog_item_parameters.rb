# Productos y servicios › Parámetros — lo que el producto toma de las listas de la cuenta:
#
#   catalog_category   su categoría; copia el texto completo («Refacciones › Frenos») en category
#   catalog_unit       su unidad; copia la abreviatura («pza») en unit
#   tax_rate           su impuesto; sin él, el de por omisión de la cuenta
#   price_includes_tax el precio ya trae el impuesto: al cotizar se separa (quote_unit_price)
#   sat_code           clave SAT de producto o servicio (opcional, para facturar)
#   withholding_rate_ids  sus retenciones (Ret. IVA, Ret. ISR…): pasan a la partida; la cotización las resta solo
#                      si el cliente es persona moral
#
# Si llega solo el texto (importar CSV, API) se busca en la lista y, si no está, se crea.
module CatalogItemParameters
  extend ActiveSupport::Concern

  included do
    belongs_to :catalog_category, optional: true
    belongs_to :catalog_unit, optional: true
    belongs_to :tax_rate, optional: true

    before_validation :link_parameters
    validate :parameters_of_account
  end

  # El impuesto que lleva: el suyo o el de por omisión (nil si la cuenta aún no tiene lista).
  def effective_tax_rate = tax_rate || (account && TaxRate.default_for(account))

  def quote_tax_percent
    rate = effective_tax_rate
    return rate.percent if rate

    account ? CaseSetting.for_account(account).default_tax_percent : 0
  end

  def withholding_rates
    return TaxRate.none if withholding_rate_ids.blank? || account.nil?

    account.tax_rates.withholding.where(id: withholding_rate_ids).order(:id)
  end

  # Lo que se copia a la partida: [{ 'id', 'name', 'percent' }]
  def quote_withholdings = withholding_rates.map(&:snapshot)

  # El precio para la partida: sin el impuesto si el precio ya lo incluye.
  def quote_unit_price
    return price unless price_includes_tax?

    (price.to_d / (1 + (quote_tax_percent.to_d / 100))).round(2)
  end

  private

  def link_parameters
    self.sat_code = sat_code.to_s.strip.upcase.presence
    self.withholding_rate_ids = Array(withholding_rate_ids).compact_blank.map(&:to_i).uniq
    link_category
    link_unit
  end

  def link_category
    if catalog_category_id_changed?
      self.category = catalog_category&.path
    elsif category_changed? && account
      self.catalog_category = CatalogParameters.category_for(account, category)
      self.category = catalog_category&.path
    end
  end

  def link_unit
    if catalog_unit_id_changed?
      self.unit = catalog_unit&.abbreviation
    elsif unit_changed? && account
      self.catalog_unit = CatalogParameters.unit_for(account, unit)
      self.unit = catalog_unit&.abbreviation
    end
  end

  def parameters_of_account
    { catalog_category: catalog_category, catalog_unit: catalog_unit, tax_rate: tax_rate }.each do |field, record|
      errors.add(field, :invalid) if record && record.account_id != account_id
    end
    withholdings_valid
  end

  # El impuesto es trasladado; las retenciones, de la cuenta y de tipo retención.
  def withholdings_valid
    errors.add(:tax_rate, :invalid) if tax_rate&.withholding?
    errors.add(:withholding_rate_ids, :invalid) if withholding_rate_ids.any? && withholding_rates.count != withholding_rate_ids.size
  end
end
