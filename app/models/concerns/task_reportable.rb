# Reporte de cierre — lo que se concluye con reporte: tareas y tareas agendadas. Al
# concluirse, su reporte pendiente queda cerrado. Lo que se concluye solo no lleva reporte.
module TaskReportable
  extend ActiveSupport::Concern

  included do
    has_many :task_reports, dependent: :nullify
    after_update_commit :close_task_report, if: -> { saved_change_to_status? && concluded? }
  end

  def report_ready?
    task_reports.pending_close.exists?
  end

  private

  def close_task_report
    task_reports.pending_close.find_each(&:close!)
  end
end
