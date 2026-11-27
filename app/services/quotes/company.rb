# Cotizaciones › Formatos — los datos de la empresa que salen en el encabezado: una sola vez en la cuenta
# (case_settings.company_profile + logo de la empresa) y, si un formato lo pide, cambiados en ese formato
# (otra razón social, otro teléfono…). Sin razón social, el nombre de la cuenta.
#
#   Quotes::Company.for(account, format) → { 'legal_name', 'tax_id', 'address', 'phone', 'email', 'website' }
#   Quotes::Company.logo(account, format) → el logo del formato o el de la empresa (ActiveStorage) o nil
module Quotes::Company
  MAX = { 'address' => 300 }.freeze

  module_function

  def for(account, format = nil)
    profile = clean(CaseSetting.for_account(account).company_profile.to_h)
    own = format ? format.config.dig('header', 'company').to_h.compact_blank : {}
    data = profile.merge(own)
    data['legal_name'] = data['legal_name'].presence || account.name
    data
  end

  def logo(account, format = nil)
    return format.logo if format&.logo&.attached?

    setting = CaseSetting.for_account(account)
    setting.company_logo if setting.company_logo.attached?
  end

  def clean(raw)
    QuoteFormat::COMPANY_FIELDS.index_with { |key| raw[key].to_s.strip.first(MAX.fetch(key, 120)).presence }.compact
  end
end
