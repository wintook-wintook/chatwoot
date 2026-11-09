# frozen_string_literal: true

# Tareas con el cliente — lo que el controlador de tareas del caso agrega a cada tarea
# (quién la hace, su avance en el portal) y el aviso al cliente al crearla.
module ClientTaskFields
  extend ActiveSupport::Concern

  private

  # Tareas con el cliente — al crearla, avisarle al cliente con el enlace de su portal (si se pidió).
  def notify_client(task)
    return unless task.for_client? && ActiveModel::Type::Boolean.new.cast(params[:notify_client])

    ClientTasks::Notifier.new(task, current_user).call(:assigned)
  end

  # Tareas con el cliente — quién la hace, su avance en el portal y cuánto ha pasado ahí.
  def client_fields(task)
    { audience: task.audience, requires_file: task.requires_file, client_status: task.client_status,
      cancel_reason: task.cancel_reason, work_started: Cases::Cancellation.work_started?(task),
      completed_by_contact: task.completed_by_contact&.name, client_entries_count: client_entries_map[task.id] || 0,
      # Agendarla la quita (se vuelve tarea agendada) o, si no se puede, deja una sesión ligada.
      replaceable: Cases::Conversion.task_kind_replaceable?(task) }
  end

  def client_entries_map
    @client_entries_map ||= CaseTaskClientEntry.where(case_ticket_id: @ticket.id).group(:case_task_id).count
  end
end
