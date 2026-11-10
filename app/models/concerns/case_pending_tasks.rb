# Al cerrarse o cancelarse, el caso queda de solo lectura: ninguna tarea se queda pendiente
# adentro. Pasa por cualquier camino (a mano, en lote, reglas, SLA, tablero). Lo normal es
# cancelarlas; quien cierra a mano puede pedir conservarlas sin caso (`pending_tasks_decision`).
module CasePendingTasks
  extend ActiveSupport::Concern

  FROZEN_STATUSES = %w[closed cancelled].freeze

  included do
    attr_accessor :pending_tasks_decision

    after_update :settle_pending_tasks, if: -> { saved_change_to_status? && frozen_for_edit? }
    after_update :restore_closed_tasks, if: -> { saved_change_to_status? && !frozen_for_edit? && FROZEN_STATUSES.include?(status_before_last_save) }
  end

  private

  def settle_pending_tasks
    Cases::PendingTasksOnClose.new(self, keep: pending_tasks_decision.to_s == 'keep').call
  end

  # Se reabrió: lo que se canceló por el cierre vuelve a estar pendiente.
  def restore_closed_tasks
    case_tasks.cancelled.where(cancel_reason: Cases::PendingTasksOnClose::REASON)
              .update_all(status: CaseTask.statuses[:pending], cancelled_at: nil, cancel_reason: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
