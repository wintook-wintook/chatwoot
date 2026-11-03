# frozen_string_literal: true

# Plan Actividad del caso — la tarea deja huella en la bitácora de su caso: creada,
# completada, cancelada, reabierta o borrada. Las de plantilla no se anotan al nacer
# (ya va un stage_tasks_added) y las que cancela el cierre del caso tampoco
# (van por update_all y el cierre deja su propia nota).
module CaseTaskActivity
  extend ActiveSupport::Concern

  STATUS_EVENTS = { 'done' => :task_completed, 'cancelled' => :task_cancelled, 'pending' => :task_reopened }.freeze

  included do
    after_create_commit :log_task_created, if: -> { case_ticket_id && case_type_column_task_id.nil? && documentation_for_column_id.nil? }
    after_update_commit :log_task_status, if: -> { case_ticket_id && saved_change_to_status? }
    after_destroy_commit :log_task_deleted, if: :case_ticket_id
  end

  private

  def log_task_created
    log_task_event(:task_created, assignee: assignee&.name, due_at: due_at)
  end

  def log_task_status
    log_task_event(STATUS_EVENTS.fetch(status), from: status_before_last_save)
  end

  # Si se borró el caso entero, no hay bitácora que anotar.
  def log_task_deleted
    return unless CaseTicket.exists?(case_ticket_id)

    log_task_event(:task_deleted, task_id: nil)
  end

  def log_task_event(type, task_id: id, **extra)
    CaseEvent.create!(account_id: account_id, case_ticket_id: case_ticket_id, case_task_id: task_id,
                      event_type: type, origin: Current.user ? :agent : :system, actor: Current.user,
                      payload: { sequence: sequence, title: title }.merge(extra.compact))
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] bitácora de la tarea #{id}: #{e.message}")
  end
end
