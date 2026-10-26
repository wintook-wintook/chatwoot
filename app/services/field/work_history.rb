# Plan-Trabajo-Campo — «Mis trabajos»: las órdenes que el técnico ya terminó en
# un periodo, con sus horas (las que él registró en la orden) y la calificación
# del cliente. Suyas = es el responsable o registró horas en ella.
# La fecha de terminado es la de entrega (`received_at`), o la de resuelto/cerrado.
class Field::WorkHistory
  DONE_AT = 'COALESCE(case_tickets.received_at, case_tickets.resolved_at, case_tickets.closed_at)'.freeze

  def initialize(scope, user, from, to)
    @scope = scope
    @user = user
    @range = from.beginning_of_day..to.end_of_day
  end

  def as_json(*)
    rows = orders.map { |order| row(order) }
    rated = rows.filter_map { |r| r[:csat_rating] }
    {
      from: @range.begin.to_date, to: @range.end.to_date, orders: rows,
      totals: { orders: rows.size, minutes: rows.sum { |r| r[:minutes] },
                csat_count: rated.size, csat_average: rated.any? ? (rated.sum.to_f / rated.size).round(1) : nil }
    }
  end

  private

  def orders
    @orders ||= @scope.where(case_type_id: CaseType.where(case_class: :work_order).select(:id))
                      .where(status: ServiceReportable::COMPLETION_STATUSES)
                      .where("#{DONE_AT} BETWEEN :from AND :to", from: @range.begin, to: @range.end)
                      .where('case_tickets.assignee_id = :me OR case_tickets.id IN (:logged)',
                             me: @user.id, logged: CaseTimeEntry.where(user_id: @user.id).select(:case_ticket_id))
                      .includes(:contact).order(Arel.sql("#{DONE_AT} DESC")).to_a
  end

  def row(order)
    {
      id: order.id, folio: order.folio, title: order.title, status: order.status,
      contact: order.contact && { id: order.contact.id, name: order.contact.name },
      done_at: order.received_at || order.resolved_at || order.closed_at,
      minutes: minutes_by_order[order.id].to_i, csat_rating: order.csat_rating
    }
  end

  def minutes_by_order
    @minutes_by_order ||= CaseTimeEntry.where(user_id: @user.id, case_ticket_id: orders.map(&:id)).group(:case_ticket_id).sum(:minutes)
  end
end
