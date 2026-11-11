# frozen_string_literal: true

# El siguiente paso de cada caso abierto: lo más próximo entre sus tareas pendientes y
# sus tareas agendadas activas. Sin ninguno, el caso se queda sin continuidad («Sin
# siguiente paso»). Por lote: dos consultas para toda la página de la lista o el tablero.
#   Cases::NextSteps.for(tickets) → { ticket_id => { kind:, at:, overdue:, more: } }
#   kind: task | meeting | none. Los cerrados y cancelados no entran (no aplica).
module Cases::NextSteps
  CLOSED = %w[closed cancelled].freeze

  module_function

  def for(tickets)
    ids = tickets.reject { |t| CLOSED.include?(t.status) }.map(&:id)
    return {} if ids.empty?

    items = items_for(ids)
    ids.index_with { |id| summary(items[id] || []) }
  end

  # Abiertos sin tareas pendientes ni agendadas activas. Las tareas sin caso (case_ticket_id
  # NULL) se excluyen de las subconsultas: un NOT IN con NULL no devolvería nada.
  def without_next_step(scope)
    scope.where.not(status: CLOSED)
         .where.not(id: CaseTask.pending.where.not(case_ticket_id: nil).select(:case_ticket_id))
         .where.not(id: CaseMeeting.active.where.not(case_ticket_id: nil).select(:case_ticket_id))
  end

  def items_for(ids)
    (task_items(ids) + meeting_items(ids)).group_by(&:first).transform_values { |list| list.map(&:last) }
  end

  # La fecha de la tarea: su vencimiento o, si no, el fin del día programado.
  def task_items(ids)
    CaseTask.pending.where(case_ticket_id: ids).pluck(:case_ticket_id, :due_at, :planned_on).map do |id, due, planned|
      at = due || planned&.in_time_zone&.end_of_day
      [id, { kind: 'task', at: at, overdue: overdue?(at) }]
    end
  end

  def meeting_items(ids)
    CaseMeeting.active.where(case_ticket_id: ids).pluck(:case_ticket_id, :starts_at)
               .map { |id, starts| [id, { kind: 'meeting', at: starts, overdue: overdue?(starts) }] }
  end

  def overdue?(time)
    time.present? && time < Time.current
  end

  # Lo más próximo con fecha; si nada tiene fecha, la tarea sin fecha.
  def summary(items)
    return { kind: 'none' } if items.empty?

    first = items.select { |i| i[:at] }.min_by { |i| i[:at] } || items.first
    first.merge(more: items.size - 1)
  end
end
