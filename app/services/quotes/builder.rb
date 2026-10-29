# Plan-Catalogo-Cotizaciones V1 — arma cotizaciones: la nueva (con los valores de
# la cuenta y, si la empresa lo exige, su oportunidad), la nueva versión (la
# anterior queda cancelada «Reemplazada por vN») y la oportunidad que se liga.
class Quotes::Builder
  Error = Class.new(StandardError)
  VALID_DAYS = 15

  def initialize(account, actor)
    @account = account
    @actor = actor
    @settings = CaseSetting.for_account(account)
  end

  def create!(attrs, create_opportunity: false)
    quote = @account.quotes.new(attrs)
    apply_defaults(quote, attrs)
    quote.save!
    quote.update!(opportunity: create_opportunity(quote)) if needs_opportunity?(quote, create_opportunity)
    quote
  end

  def new_version(quote)
    Quote.transaction do
      copy = @account.quotes.create!(
        quote.attributes.slice(*%w[contact_id assignee_id opportunity_id origin_ticket_id currency terms notes number])
             .merge(version: next_version(quote), parent_quote: quote, valid_until: VALID_DAYS.days.from_now.to_date)
      )
      quote.items.each do |item|
        copy.items.create!(item.attributes.except('id', 'quote_id', 'created_at', 'updated_at'))
      end
      copy.recalculate!
      replace(quote, copy) if quote.live?
      copy
    end
  end

  # Oportunidad nueva del cliente, con el monto y la moneda de la cotización.
  def create_opportunity(quote)
    type = @account.case_types.where(case_class: :commercial, retired_at: nil).order(:position).first
    raise Error, I18n.t('quotes.errors.no_sales_type') unless type

    CaseTicket.create!(account: @account, contact: quote.contact, case_type: type, origin: :manual,
                       title: I18n.t('quotes.opportunity_title', folio: quote.folio),
                       assignee: quote.assignee, assignee_type: quote.assignee ? :agent : :bot,
                       amount: quote.total, currency: quote.currency)
  end

  private

  def apply_defaults(quote, attrs)
    quote.contact = @account.contacts.find(attrs[:contact_id]) if attrs[:contact_id].present?
    quote.assignee = @account.users.find_by(id: attrs[:assignee_id]) || @actor
    quote.currency = quote.currency.presence || @settings.default_currency
    quote.valid_until ||= VALID_DAYS.days.from_now.to_date
  end

  def needs_opportunity?(quote, requested)
    quote.opportunity.nil? && (requested || @settings.quotes_require_opportunity)
  end

  def next_version(quote)
    @account.quotes.where(number: quote.number).maximum(:version).to_i + 1
  end

  def replace(quote, copy)
    Quotes::OpportunitySync.without_loop do
      quote.update!(status: :cancelled, decided_at: Time.current,
                    outcome_note: I18n.t('quotes.replaced_by', version: copy.version))
    end
  end
end
