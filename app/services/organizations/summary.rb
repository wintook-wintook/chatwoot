# Plan-Organizaciones O2 — lo de una organización en un vistazo (su página): oportunidades,
# casos, cotizaciones, contratos y equipos, con lo que el usuario puede ver. Los montos
# solo con «Ver montos».
class Organizations::Summary
  LIMIT = 20

  def initialize(organization:, grant:)
    @organization = organization
    @account = organization.account
    @grant = grant
  end

  def as_json
    tickets = @grant.case_tickets(@account.case_tickets).where(organization_id: @organization.id)
    commercial = tickets.commercial
    {
      opportunities: tickets_json(commercial),
      cases: tickets_json(tickets.where.not(id: commercial.select(:id))),
      quotes: quotes.map { |q| quote_json(q) },
      contracts: contracts.map { |c| contract_json(c) },
      assets: assets.map { |a| a.slice(:id, :name, :brand, :model, :contact_id, :active) }
    }
  end

  private

  def amounts?
    @grant.can?(:see_amounts)
  end

  def quotes
    @grant.quotes(@account.quotes).where(organization_id: @organization.id).order(created_at: :desc).limit(LIMIT)
  end

  def contracts
    visible = @grant.contacts(@account.contacts).select(:id)
    @account.contracts.where(organization_id: @organization.id, contact_id: visible).order(created_at: :desc).limit(LIMIT)
  end

  def assets
    @account.customer_assets.where(organization_id: @organization.id).ordered.limit(LIMIT)
  end

  def tickets_json(scope)
    scope.order(created_at: :desc).limit(LIMIT).map { |ticket| ticket_json(ticket) }
  end

  def ticket_json(ticket)
    ticket.slice(:id, :folio, :title, :status, :outcome, :contact_id, :created_at)
          .merge(amount: (ticket.amount&.to_f if amounts?), currency: ticket.currency)
  end

  def quote_json(quote)
    quote.slice(:id, :number, :version, :status, :contact_id, :created_at)
         .merge(total: (quote.total.to_f if amounts?), currency: quote.currency)
  end

  def contract_json(contract)
    contract.slice(:id, :title, :contact_id, :next_charge_on, :ends_on)
            .merge(state: contract.state, amount: (contract.amount.to_f if amounts?), currency: contract.currency)
  end
end
