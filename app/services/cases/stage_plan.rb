# frozen_string_literal: true

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T2: el camino de tareas del caso
# para la pestaña Tareas. `current` es la etapa en la que está; `upcoming`, las
# etapas siguientes que tienen tareas en su plantilla (se muestran en gris como
# «Próximas»; todavía no son tareas del caso). Las etapas de caso cerrado no
# cuentan: ahí las tareas ya son de solo lectura.
class Cases::StagePlan
  CLOSED = %w[closed cancelled].freeze

  def initialize(ticket)
    @ticket = ticket
  end

  def as_json(*)
    current = @ticket.current_stage_column
    { current: current && { id: current.id, label: current.label }, upcoming: upcoming(current) }
  end

  private

  def upcoming(current)
    return [] if current.nil? || @ticket.frozen_for_edit?

    columns = @ticket.case_type.case_type_columns.ordered.includes(:task_templates).to_a
    after = columns.drop(columns.index(current) + 1)
    after.reject { |c| c.task_templates.empty? || (c.statuses - CLOSED).empty? }.map do |c|
      { id: c.id, label: c.label, tasks: c.task_templates.map { |t| { title: t.title, required: t.required } } }
    end
  end
end
