# Cotizaciones › Formatos — la cotización con la que se ve la vista previa del diseñador: la que se pidió (si la
# puede ver), la más reciente con partidas o, si no hay, una de ejemplo sin guardar.
module Quotes::SampleQuote
  module_function

  def for(account, user, grant, quote_id = nil)
    visible = grant.quotes(account.quotes).includes(:items, :contact, :assignee)
    (quote_id.present? && visible.find_by(id: quote_id)) || visible.joins(:items).order(created_at: :desc).first ||
      example(account, user)
  end

  def example(account, user)
    quote = account.quotes.new(number: 1, version: 1, currency: CaseSetting.for_account(account).default_currency,
                               valid_until: 15.days.from_now.to_date, assignee: user, apply_withholdings: false,
                               contact: account.contacts.new(name: 'Cliente de ejemplo', email: 'cliente@ejemplo.com',
                                                             phone_number: '+525512345678'))
    quote.items.build(description: 'Servicio de instalación', quantity: 1, unit: 'serv', unit_price: 2500, tax_percent: 16)
    quote.items.build(description: 'Equipo modelo X200', quantity: 2, unit: 'pza', unit_price: 1800, discount_percent: 10,
                      tax_percent: 16)
    quote
  end
end
