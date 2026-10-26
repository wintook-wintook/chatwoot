# Plan-Catalogo-Cotizaciones V1 — JSON de una cotización para la pantalla. Sin
# «Ver montos» (y si no es suya) los importes viajan vacíos.
class Quotes::Serializer
  def initialize(quote, grant:)
    @quote = quote
    @grant = grant
  end

  def as_json(full: false)
    json = base
    json.merge!(details) if full
    amounts? ? json : json.merge(subtotal: nil, discount_total: nil, tax_total: nil, total: nil)
  end

  def self.public_url(quote)
    "#{ENV.fetch('FRONTEND_URL', '')}/cotizacion/#{quote.public_token}"
  end

  private

  def amounts?
    @grant.nil? || @grant.quote_amounts_visible?(@quote)
  end

  def base
    q = @quote
    { id: q.id, folio: q.folio, number: q.number, version: q.version, status: q.status, expired: q.expired?,
      currency: q.currency, subtotal: q.subtotal.to_f, discount_total: q.discount_total.to_f,
      tax_total: q.tax_total.to_f, total: q.total.to_f, public_url: self.class.public_url(q) }
      .merge(dates).merge(links)
  end

  def dates
    q = @quote
    { valid_until: q.valid_until, sent_at: q.sent_at, viewed_at: q.viewed_at, decided_at: q.decided_at,
      postponed_until: q.postponed_until, created_at: q.created_at, outcome_note: q.outcome_note,
      accepted_by_name: q.accepted_by_name }
  end

  def links
    q = @quote
    { contact: q.contact && { id: q.contact.id, name: q.contact.name },
      assignee: q.assignee && { id: q.assignee.id, name: q.assignee.name },
      opportunity: ticket_ref(q.opportunity), origin_ticket: ticket_ref(q.origin_ticket),
      outcome_reason: q.outcome_reason && { id: q.outcome_reason.id, label: q.outcome_reason.label } }
  end

  def details
    {
      terms: @quote.terms, notes: @quote.notes, editable: @quote.editable?,
      opportunity_quotes: @quote.opportunity ? @quote.opportunity.quotes.where.not(id: @quote.id).live.count : 0,
      items: @quote.items.map { |item| item_json(item) }
    }
  end

  def item_json(item)
    row = { id: item.id, catalog_item_id: item.catalog_item_id, description: item.description, kind: item.kind,
            unit: item.unit, quantity: item.quantity.to_f, unit_price: item.unit_price.to_f,
            discount_percent: item.discount_percent.to_f, tax_percent: item.tax_percent.to_f, total: item.total.to_f }
    amounts? ? row : row.merge(unit_price: nil, total: nil)
  end

  def ticket_ref(ticket)
    return unless ticket

    { id: ticket.id, folio: ticket.folio, title: ticket.title, status: ticket.status, outcome: ticket.outcome,
      case_class: ticket.case_type&.case_class || 'support' }
  end
end
