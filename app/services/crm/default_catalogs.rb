# CrmZeus O0/A0 — catálogos con los que arranca una cuenta: México con sus 32 estados (clave
# c_Estado del SAT), peso mexicano como moneda local, «Contado» como condición de pago y,
# para artículos, IVA 16 % / IVA 0 % / Exento, «Precio de lista» y las unidades pieza y servicio.
# Idempotente: solo crea lo que falta y no toca lo que la cuenta ya editó.
class Crm::DefaultCatalogs
  MEXICAN_STATES = {
    'AGU' => 'Aguascalientes', 'BCN' => 'Baja California', 'BCS' => 'Baja California Sur', 'CAM' => 'Campeche',
    'CHP' => 'Chiapas', 'CHH' => 'Chihuahua', 'CMX' => 'Ciudad de México', 'COA' => 'Coahuila', 'COL' => 'Colima',
    'DUR' => 'Durango', 'GUA' => 'Guanajuato', 'GRO' => 'Guerrero', 'HID' => 'Hidalgo', 'JAL' => 'Jalisco',
    'MEX' => 'Estado de México', 'MIC' => 'Michoacán', 'MOR' => 'Morelos', 'NAY' => 'Nayarit', 'NLE' => 'Nuevo León',
    'OAX' => 'Oaxaca', 'PUE' => 'Puebla', 'QUE' => 'Querétaro', 'ROO' => 'Quintana Roo', 'SLP' => 'San Luis Potosí',
    'SIN' => 'Sinaloa', 'SON' => 'Sonora', 'TAB' => 'Tabasco', 'TAM' => 'Tamaulipas', 'TLA' => 'Tlaxcala',
    'VER' => 'Veracruz', 'YUC' => 'Yucatán', 'ZAC' => 'Zacatecas'
  }.freeze

  def self.ensure!(account)
    new(account).ensure!
  end

  def initialize(account)
    @account = account
  end

  def ensure!
    ActiveRecord::Base.transaction do
      ensure_mexico
      ensure_local_currency
      ensure_cash_payment_term
      ensure_article_catalogs
    end
  end

  private

  def ensure_mexico
    return if CrmCountry.exists?(account: @account)

    mexico = CrmCountry.create!(account: @account, name: 'México', abbreviation: 'MX', iso_code: 'MEX', is_default: true)
    MEXICAN_STATES.each { |code, name| mexico.states.create!(account: @account, name: name, abbreviation: code) }
  end

  def ensure_local_currency
    return if CrmCurrency.exists?(account: @account)

    CrmCurrency.create!(account: @account, name: 'Peso mexicano', iso_code: 'MXN', symbol: '$',
                        amount_in_words: 'PESOS/M.N.', is_local: true, is_default: true)
  end

  def ensure_cash_payment_term
    return if CrmPaymentTerm.exists?(account: @account)

    CrmPaymentTerm.create!(account: @account, name: 'Contado', is_default: true)
  end

  # Artículos: IVA 16 % (predeterminado), IVA 0 % y Exento; «Precio de lista»; pieza y servicio.
  def ensure_article_catalogs
    unless CrmTax.exists?(account: @account)
      CrmTax.create!(account: @account, name: 'IVA 16%', tax_type: :vat, percent: 16, is_default: true)
      CrmTax.create!(account: @account, name: 'IVA 0%', tax_type: :vat, percent: 0)
      CrmTax.create!(account: @account, name: 'Exento', tax_type: :vat_exempt, percent: 0)
    end
    unless CrmLookup.price_list.exists?(account: @account)
      CrmLookup.create!(account: @account, kind: :price_list, name: 'Precio de lista', is_default: true)
    end
    return if CrmUnit.exists?(account: @account)

    CrmUnit.create!(account: @account, name: 'Pieza', sat_key: 'H87', is_default: true)
    CrmUnit.create!(account: @account, name: 'Servicio', sat_key: 'E48')
  end
end
