# Plan-Catalogo-Cotizaciones V1 — cuando el cliente acepta una cotización que
# salió de un caso, lo aceptado pasa a ese caso:
#   · orden de trabajo → sus partidas se agregan como materiales y servicios;
#   · proyecto → se crea una orden de trabajo nueva dentro del proyecto con ellas;
#   · soporte u oportunidad → nada (el caso ya muestra la cotización ganada).
class Quotes::ApplyToOrigin
  def self.call(quote)
    new(quote).call
  end

  def initialize(quote)
    @quote = quote
    @origin = quote.origin_ticket
  end

  def call
    return if @origin.nil?

    if @origin.work_order?
      add_items_to(@origin)
    elsif @origin.project?
      order = create_order_in_project
      add_items_to(order) if order
    end
  end

  private

  def add_items_to(order)
    start = order.work_order_items.maximum(:position).to_i + 1
    @quote.items.each_with_index do |item, index|
      order.work_order_items.create!(account: order.account, description: item.description, quantity: item.quantity,
                                     unit: item.unit, unit_cost: item.unit_price, position: start + index)
    end
  end

  def create_order_in_project
    type = @quote.account.case_types.where(case_class: :work_order, retired_at: nil).order(:position).first
    return if type.nil? || !@quote.account.feature_enabled?('case_work_order')

    order = CaseTicket.create!(account: @quote.account, contact: @origin.contact, case_type: type, origin: :manual,
                               title: "#{@quote.folio} · #{@origin.title}".truncate(255), assignee: @origin.assignee,
                               assignee_type: @origin.assignee ? :agent : :bot)
    CaseTicketRelation.create!(account: @quote.account, ticket: order, related_ticket: @origin, relation_type: :project_member)
    order
  end
end
