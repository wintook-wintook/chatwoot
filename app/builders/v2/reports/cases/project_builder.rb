# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Proyecto P3
#
# Métricas de proyectos, solo sobre casos de esa clase. Como las de órdenes:
#   - Lo ABIERTO es foto de hoy: salud de cada proyecto abierto contra su plan,
#     fases, hitos vencidos y horas reales contra presupuesto.
#   - Lo TERMINADO se acota por el día en que se terminó (resolved_at o closed_at)
#     dentro del rango: entregas a tiempo = terminado a más tardar su fecha objetivo.
# Salud de un abierto:
#   - late     → la fecha objetivo ya pasó;
#   - at_risk  → su avance va más de RISK_GAP puntos detrás de lo que debería según el
#                tiempo transcurrido entre inicio y fecha objetivo;
#   - on_track → va al ritmo (o adelante);
#   - no_dates → le falta inicio o fecha objetivo (no se puede comparar).
class V2::Reports::Cases::ProjectBuilder < V2::Reports::Cases::BaseBuilder
  RISK_GAP = 20
  FINISHED_STATUSES = %w[resolved validating closed].freeze
  FINISHED_ON = 'COALESCE(case_tickets.resolved_at, case_tickets.closed_at)'
  HEALTH_KEYS = %w[on_track at_risk late no_dates].freeze

  def build
    {
      summary: summary,
      health: health_counts,
      stages: stages,
      by_assignee: breakdown(:assignee_id),
      by_type: breakdown(:case_type_id)
    }
  end

  private

  def projects
    filtered_tickets.of_class('project')
  end

  def open_scope
    projects.where(status: CaseTicket::PENDING_STATUSES + %w[resolved validating])
  end

  def finished_scope
    scope = projects.where(status: FINISHED_STATUSES)
    range ? scope.where("#{FINISHED_ON} BETWEEN ? AND ?", range.begin, range.end) : scope
  end

  # Una fila por proyecto abierto: su salud, avance y horas (el avance y las
  # horas salen del resumen del propio proyecto, el mismo de la ficha).
  def open_rows
    @open_rows ||= open_scope.includes(:case_type_column, case_type: :case_type_columns).map do |project|
      summary = project.project_progress_summary
      { assignee_id: project.assignee_id, case_type_id: project.case_type_id, health: health_of(project, summary),
        stage: stage_label(project), actual_hours: summary[:actual_hours], budget_hours: project.budget_hours.to_f }
    end
  end

  def finished_rows
    @finished_rows ||= finished_scope.map do |project|
      finished_on = (project.resolved_at || project.closed_at).to_date
      { assignee_id: project.assignee_id, case_type_id: project.case_type_id,
        on_time: project.project_due_on.nil? ? nil : finished_on <= project.project_due_on }
    end
  end

  def health_of(project, summary)
    return 'late' if project.project_overdue?
    return 'no_dates' unless project.project_start_on && project.project_due_on

    expected = expected_progress(project.project_start_on, project.project_due_on)
    (expected - summary[:progress].to_i) > RISK_GAP ? 'at_risk' : 'on_track'
  end

  # % del plazo ya transcurrido (0–100).
  def expected_progress(start_on, due_on)
    total = (due_on - start_on).to_f
    return 100 if total <= 0

    (((Date.current - start_on) / total) * 100).clamp(0, 100)
  end

  # ── Resumen ──────────────────────────────────────────────────────────────────

  def summary
    counts = health_tally(open_rows)
    {
      open_count: open_rows.size,
      late_count: counts['late'],
      at_risk_count: counts['at_risk'],
      overdue_milestones_count: overdue_milestones_count,
      over_budget_count: open_rows.count { |r| r[:budget_hours].positive? && r[:actual_hours] > r[:budget_hours] }
    }.merge(hours_summary(open_rows), delivery_summary(finished_rows))
  end

  def hours_summary(rows)
    budget = rows.sum { |r| r[:budget_hours] }
    actual = rows.sum { |r| r[:actual_hours] }
    { budget_hours: budget.round(2), actual_hours: actual.round(2),
      hours_used: budget.zero? ? nil : (actual / budget * 100).round }
  end

  def delivery_summary(rows)
    dated = rows.reject { |r| r[:on_time].nil? }
    on_time = dated.count { |r| r[:on_time] }
    { finished_count: rows.size, delivered_on_time_count: on_time,
      delivered_late_count: dated.size - on_time, on_time_rate: rate(on_time, dated.size) }
  end

  # Hitos pendientes con fecha ya pasada, de proyectos abiertos.
  def overdue_milestones_count
    CaseTask.where(case_ticket_id: open_scope.select(:id), milestone: true, status: :pending)
            .where(due_at: ...Time.current).count
  end

  def health_tally(rows)
    HEALTH_KEYS.index_with { |key| rows.count { |r| r[:health] == key } }
  end

  def health_counts
    health_tally(open_rows).map { |key, n| { key: key, count: n } }
  end

  # ── Fases ────────────────────────────────────────────────────────────────────

  def stages
    open_rows.group_by { |r| r[:stage]&.label }.map { |label, rows| stage_row(label, rows) }
             .sort_by { |row| [row[:position], row[:label].to_s] }
  end

  def stage_row(label, rows)
    positions = rows.filter_map { |r| r[:stage]&.position }
    { label: label, position: positions.min || 999, count: rows.size }
  end

  # La columna que pinta el Tablero: la guardada si cubre el estado, si no la
  # primera del tipo que lo cubre.
  def stage_label(project)
    pointed = project.case_type_column
    return pointed if pointed&.statuses&.include?(project.status)

    columns = project.case_type ? project.case_type.case_type_columns.sort_by(&:position) : []
    columns.find { |col| col.statuses.include?(project.status) }
  end

  # ── Por responsable y por tipo ───────────────────────────────────────────────

  def breakdown(key)
    open_grouped = open_rows.group_by { |r| r[key] }
    finished_grouped = finished_rows.group_by { |r| r[key] }
    ids = (open_grouped.keys + finished_grouped.keys).uniq
    names = names_for(key, ids.compact)
    rows = ids.map { |id| breakdown_row(id, names[id], open_grouped[id] || [], finished_grouped[id] || []) }
    rows.sort_by { |r| [-r[:open_count], -r[:finished_count]] }
  end

  def breakdown_row(id, name, open, finished)
    counts = health_tally(open)
    { id: id, name: name, open_count: open.size, late_count: counts['late'], at_risk_count: counts['at_risk'] }
      .merge(hours_summary(open), delivery_summary(finished))
  end

  def names_for(key, ids)
    source = key == :assignee_id ? account.users : account.case_types
    source.where(id: ids).pluck(:id, :name).to_h
  end

  def rate(part, total)
    total.zero? ? nil : (part.to_f / total * 100).round
  end
end
