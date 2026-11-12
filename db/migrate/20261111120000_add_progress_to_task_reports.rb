# Reportar avance: un reporte de una tarea que NO la completa (se cierra al guardarse). Y los
# reportes dejan de ser notas en la bitácora del caso: tienen su propio movimiento
# (case_events.event_type task_reported = 56), así la pestaña Notas es solo lo escrito a mano.
class AddProgressToTaskReports < ActiveRecord::Migration[7.0]
  INTERNAL_NOTE = 16
  TASK_REPORTED = 56

  def up
    add_column :task_reports, :progress, :boolean, null: false, default: false
    execute <<~SQL.squish
      UPDATE case_events SET event_type = #{TASK_REPORTED}
      WHERE event_type = #{INTERNAL_NOTE} AND payload->>'kind' IN ('task_report', 'activity_report')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE case_events SET event_type = #{INTERNAL_NOTE} WHERE event_type = #{TASK_REPORTED}
    SQL
    remove_column :task_reports, :progress
  end
end
