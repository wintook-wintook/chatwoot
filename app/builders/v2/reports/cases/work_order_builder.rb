# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F3
#
# Métricas de órdenes de trabajo, solo sobre casos de esa clase. Dos relojes, como
# el embudo comercial:
#   - Lo ABIERTO (etapas, visitas vencidas) es una foto de hoy, sin fecha.
#   - Lo TERMINADO se acota por el día en que se terminó (resolved_at o, si no,
#     closed_at) dentro del rango: «qué se terminó en el período».
# Cumplimiento: una orden terminada es «a tiempo» si se terminó a más tardar el día
# de su última visita (programada, reprogramada o realizada); «tarde» si después;
# «sin visita» si nunca se agendó. Retrabajo = se reabrió alguna vez (reopen_count).
class V2::Reports::Cases::WorkOrderBuilder < V2::Reports::Cases::BaseBuilder
  FINISHED_STATUSES = %w[resolved validating closed].freeze
  PLANNED_VISIT_STATUSES = %i[scheduled rescheduled held].freeze
  FINISHED_ON = 'COALESCE(case_tickets.resolved_at, case_tickets.closed_at)'

  def build
    {
      summary: summary,
      stages: stages,
      timing: timing_counts,
      by_assignee: breakdown(:assignee_id),
      by_type: breakdown(:case_type_id)
    }
  end

  private

  def orders
    filtered_tickets.of_class('work_order')
  end

  # Abiertas = pendientes + terminadas sin conformidad (resolved/validating).
  def open_scope
    orders.where(status: CaseTicket::PENDING_STATUSES + %w[resolved validating])
  end

  def finished_scope
    scope = orders.where(status: FINISHED_STATUSES)
    range ? scope.where("#{FINISHED_ON} BETWEEN ? AND ?", range.begin, range.end) : scope
  end

  # Una fila por orden terminada en el período (los cálculos van en Ruby: el
  # volumen es de órdenes de una cuenta y la puntualidad mira sus visitas).
  def finished_rows
    @finished_rows ||= begin
      tickets = finished_scope.to_a
      last_visit = last_visits(tickets.map(&:id))
      materials = materials_totals(tickets.map(&:id))
      tickets.map { |t| finished_row(t, last_visit[t.id], materials[t.id]) }
    end
  end

  def finished_row(ticket, last_visit_at, materials_total)
    finished_at = ticket.resolved_at || ticket.closed_at
    {
      assignee_id: ticket.assignee_id,
      case_type_id: ticket.case_type_id,
      timing: timing_of(finished_at, last_visit_at),
      estimated: ticket.estimated_hours,
      actual: ticket.actual_hours,
      rework: ticket.reopen_count.to_i.positive?,
      billable: ticket.billable,
      materials: materials_total.to_f
    }
  end

  def timing_of(finished_at, last_visit_at)
    return 'no_visit' if last_visit_at.nil?

    finished_at.to_date <= last_visit_at.to_date ? 'on_time' : 'late'
  end

  def last_visits(ids)
    CaseMeeting.where(case_ticket_id: ids, status: PLANNED_VISIT_STATUSES).group(:case_ticket_id).maximum(:starts_at)
  end

  def materials_totals(ids)
    CaseWorkOrderItem.where(case_ticket_id: ids).where.not(unit_cost: nil)
                     .group(:case_ticket_id).sum(Arel.sql('quantity * unit_cost'))
  end

  # ── Resumen ──────────────────────────────────────────────────────────────────

  def summary
    open_summary.merge(finished_summary(finished_rows))
  end

  def open_summary
    {
      open_count: open_scope.count,
      to_schedule_count: open_scope.where(status: CaseTicket::TO_SCHEDULE_STATUSES).count,
      awaiting_signoff_count: open_scope.where(status: %w[resolved validating]).count,
      # Como el filtro «Visita vencida» de la Lista: solo órdenes pendientes.
      overdue_visits_count: orders.where(status: CaseTicket::PENDING_STATUSES, id: overdue_visit_ids).count,
      cancelled_count: cancelled_count
    }
  end

  def overdue_visit_ids
    CaseMeeting.active.where(starts_at: ...Time.current).select(:case_ticket_id)
  end

  # Canceladas en el período (sin fecha propia de cancelación: la del último cambio).
  def cancelled_count
    scope = orders.where(status: :cancelled)
    (range ? scope.where(updated_at: range) : scope).count
  end

  # Mismo cálculo para el total y para cada técnico / tipo.
  def finished_summary(rows)
    { finished_count: rows.size }.merge(timing_summary(rows), hours_summary(rows), rework_summary(rows))
  end

  def timing_summary(rows)
    counts = timing_tally(rows)
    { on_time_count: counts['on_time'], late_count: counts['late'], no_visit_count: counts['no_visit'],
      on_time_rate: rate(counts['on_time'], counts['on_time'] + counts['late']) }
  end

  # Horas: solo las órdenes con estimado y real (si no, no hay contra qué comparar).
  def hours_summary(rows)
    with_hours = rows.select { |r| r[:estimated] && r[:actual] }
    estimated = with_hours.sum { |r| r[:estimated] }.to_f
    actual = with_hours.sum { |r| r[:actual] }.to_f
    { estimated_hours: estimated.round(2), actual_hours: actual.round(2), hours_orders_count: with_hours.size,
      hours_variance: estimated.zero? ? nil : ((actual - estimated) / estimated * 100).round }
  end

  def rework_summary(rows)
    reworked = rows.count { |r| r[:rework] }
    billable = rows.select { |r| r[:billable] }
    { rework_count: reworked, rework_rate: rate(reworked, rows.size), billable_count: billable.size,
      billable_materials: billable.sum { |r| r[:materials] }.round(2) }
  end

  def timing_tally(rows)
    %w[on_time late no_visit].index_with { |key| rows.count { |r| r[:timing] == key } }
  end

  # ── Etapas y puntualidad ─────────────────────────────────────────────────────

  # Abiertas por columna del tipo, agrupadas por ETIQUETA (los tipos de orden nacen
  # con el mismo flujo). La columna es la misma que pinta el Tablero: la guardada si
  # cubre el estado, si no la primera del tipo que lo cubre. Sin columna → label nil
  # («Sin etapa» en el front).
  def stages
    columns = open_scope.includes(:case_type_column, case_type: :case_type_columns).map { |t| stage_column(t) }
    columns.group_by { |col| col&.label }.map { |label, cols| stage_row(label, cols) }
           .sort_by { |row| [row[:position], row[:label].to_s] }
  end

  def stage_row(label, cols)
    { label: label, position: cols.compact.map(&:position).min || 999, count: cols.size }
  end

  def stage_column(ticket)
    pointed = ticket.case_type_column
    return pointed if pointed&.statuses&.include?(ticket.status)

    columns = ticket.case_type ? ticket.case_type.case_type_columns.sort_by(&:position) : []
    columns.find { |col| col.statuses.include?(ticket.status) }
  end

  def timing_counts
    timing_tally(finished_rows).map { |key, n| { key: key, count: n } }
  end

  # ── Por técnico y por tipo ───────────────────────────────────────────────────

  def breakdown(key)
    open_counts = open_scope.group(key).count
    grouped = finished_rows.group_by { |r| r[key] }
    ids = (open_counts.keys + grouped.keys).uniq
    names = names_for(key, ids.compact)
    rows = ids.map do |id|
      finished_summary(grouped[id] || []).merge(id: id, name: names[id], open_count: open_counts[id] || 0)
    end
    rows.sort_by { |r| [-r[:finished_count], -r[:open_count]] }
  end

  def names_for(key, ids)
    source = key == :assignee_id ? account.users : account.case_types
    source.where(id: ids).pluck(:id, :name).to_h
  end

  def rate(part, total)
    total.zero? ? nil : (part.to_f / total * 100).round
  end
end
