# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Plantilla-Tareas-Etapa T2
# ================================================================================
# Crea en el caso las tareas de la plantilla de la etapa en la que está. Se llama
# al entrar a una etapa (alta, tablero, cambio de estado) y es idempotente: una
# tarea plantilla que el caso ya tiene (pendiente o hecha) no se vuelve a crear,
# así que regresar a una etapa no duplica nada. Un caso cerrado no recibe tareas
# (sus tareas son de solo lectura).
#
# Responsable: el del caso (defecto), una persona fija o un equipo. Una tarea de
# equipo queda sin persona y con el equipo anotado, salvo que el responsable del
# caso sea de ese equipo: entonces es suya.
# ================================================================================

class Cases::StageTasksService
  def initialize(ticket)
    @ticket = ticket
  end

  def call
    column = @ticket.current_stage_column
    close_documentation_tasks(column)
    return [] if @ticket.frozen_for_edit? || column.nil?

    templates = pending_templates(column)
    return [] if templates.empty?

    tasks = CaseTask.transaction { templates.map { |template| build_task(template, column) } }
    log(column, tasks)
    Cases::StageNotifier.new(@ticket).tasks_created(column, tasks)
    tasks
  end

  private

  # T3 — la tarea «Documenta…» se completa sola cuando el caso sale de la etapa en
  # la que nació (se documentó el cierre, el resultado o la fecha al moverlo).
  def close_documentation_tasks(column)
    @ticket.case_tasks.pending.where.not(documentation_for_column_id: nil)
           .where.not(case_type_column_id: column&.id).find_each { |task| task.update!(status: :done) }
  end

  def pending_templates(column)
    taken = @ticket.case_tasks.where.not(case_type_column_task_id: nil).pluck(:case_type_column_task_id)
    column.task_templates.reject { |t| taken.include?(t.id) }
  end

  def build_task(template, column)
    @position ||= @ticket.case_tasks.count
    task = @ticket.case_tasks.create!(
      account_id: @ticket.account_id, title: template.title, description: template.description,
      priority: template.priority, estimated_minutes: template.estimated_minutes,
      due_at: template.due_after_hours && (Time.current + template.due_after_hours.hours),
      required: template.required, case_type_column_task: template, case_type_column: column,
      position: @position, **assignment(template)
    )
    @position += 1
    task
  end

  def assignment(template)
    case template.assignee_mode
    when 'user' then { assignee_id: template.assignee_id }
    when 'team' then team_assignment(template.team_id)
    else { assignee_id: @ticket.assignee_id }
    end
  end

  def team_assignment(team_id)
    in_team = @ticket.assignee_id && TeamMember.exists?(team_id: team_id, user_id: @ticket.assignee_id)
    { team_id: team_id, assignee_id: in_team ? @ticket.assignee_id : nil }
  end

  def log(column, tasks)
    @ticket.case_events.create!(
      account_id: @ticket.account_id, event_type: :stage_tasks_added, origin: :system,
      payload: { column_id: column.id, stage: column.label, count: tasks.size, titles: tasks.map(&:title).first(10) }
    )
  end
end
