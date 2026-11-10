# frozen_string_literal: true

# Lo que el menú de una tarea necesita para mostrar solo lo que sí se puede hacer:
# cuántas tareas agendadas vivas tiene («Ver tareas agendadas (N)») y si quien la ve
# la puede borrar (la creó en las primeras 24 h, o es administrador; ver CancelAndDeleteGuard).
# Con @ticket cuenta las del caso; sin él, las de @menu_task_ids (bandeja de tareas).
module TaskMenuFields
  extend ActiveSupport::Concern

  private

  def task_menu_fields(task)
    { meetings_count: task_meetings_map[task.id] || 0, deletable: task_deletable?(task) }
  end

  def task_deletable?(task)
    return true if access_grant.admin?

    task.requester_id == current_user&.id && task.created_at > CancelAndDeleteGuard::DELETE_WINDOW.ago
  end

  def task_meetings_map
    @task_meetings_map ||= begin
      scope = Current.account.case_meetings.active.where.not(case_task_id: nil)
      scope = @ticket ? scope.where(case_ticket_id: @ticket.id) : scope.where(case_task_id: Array(@menu_task_ids))
      scope.group(:case_task_id).count
    end
  end
end
