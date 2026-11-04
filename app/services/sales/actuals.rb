# Presupuesto de ventas — lo logrado (ventas ganadas, sin IVA), contado por TRATO para
# no sumar dos veces lo mismo:
#   · Oportunidad ganada → su cotización ganada (subtotal − descuento) si la tiene; si
#     no, el monto de la oportunidad. Fecha: cuando se ganó; vendedor y cliente: los de
#     la oportunidad. Sus cotizaciones nunca se cuentan aparte (una sola puede quedar
#     ganada: Quotes::OpportunitySync cancela las demás).
#   · Cotización suelta (sin oportunidad) ganada → subtotal − descuento. Fecha: cuando
#     se decidió; vendedor y cliente: los de la cotización.
# `rows` devuelve { user_id, organization_id, contact_id, currency, amount, period, at }.
# Por meses (from/to: Date) o por un rango exacto (range: Time..Time). Sin moneda, todas
# (cada renglón dice la suya: nunca se suman monedas distintas).
class Sales::Actuals
  def initialize(account:, currency: nil, user_ids: nil, from: nil, to: nil, range: nil) # rubocop:disable Metrics/ParameterLists
    @account = account
    @range = range || (from.beginning_of_month.in_time_zone.beginning_of_day..to.end_of_month.in_time_zone.end_of_day)
    @currency = currency.presence&.to_s&.upcase
    @user_ids = user_ids
  end

  # { 'MXN' => 1234.5, … }
  def totals_by_currency
    rows.group_by { |row| row[:currency] }.transform_values { |list| list.sum { |row| row[:amount] } }
  end

  def rows
    opportunity_rows + loose_quote_rows
  end

  private

  def opportunity_rows
    opportunities = @account.case_tickets.commercial.outcome_won.where(outcome_at: @range)
    opportunities = opportunities.where(assignee_id: @user_ids) if @user_ids
    list = opportunities.select(:id, :assignee_id, :organization_id, :contact_id, :amount, :currency, :outcome_at).to_a
    won = won_quotes_for(list.map(&:id))
    list.filter_map { |opportunity| opportunity_row(opportunity, won[opportunity.id]) }
  end

  def opportunity_row(opportunity, quote)
    amount, currency = quote ? [quote[:net], quote[:currency]] : [opportunity.amount, opportunity.currency]
    return if amount.nil? || !currency_match?(currency)

    row(opportunity.assignee_id, opportunity.organization_id, opportunity.contact_id, amount, opportunity.outcome_at, currency)
  end

  def won_quotes_for(opportunity_ids)
    return {} if opportunity_ids.empty?

    @account.quotes.won.where(opportunity_id: opportunity_ids).order(:decided_at, :id)
            .pluck(:opportunity_id, Arel.sql('subtotal - discount_total'), :currency)
            .to_h { |id, net, currency| [id, { net: net, currency: currency }] }
  end

  def loose_quote_rows
    quotes = @account.quotes.won.where(opportunity_id: nil, decided_at: @range)
    quotes = quotes.where(currency: @currency) if @currency
    quotes = quotes.where(assignee_id: @user_ids) if @user_ids
    quotes.pluck(:assignee_id, :organization_id, :contact_id, Arel.sql('subtotal - discount_total'), :decided_at, :currency)
          .map { |values| row(*values) } # mismo orden que `row`
  end

  def currency_match?(currency)
    @currency.nil? || currency.to_s.upcase == @currency
  end

  def row(user_id, organization_id, contact_id, amount, at, currency) # rubocop:disable Metrics/ParameterLists
    { user_id: user_id, organization_id: organization_id, contact_id: contact_id, currency: currency.to_s.upcase,
      amount: amount.to_d, period: at.in_time_zone.to_date.beginning_of_month, at: at }
  end
end
