# Tiempo dedicado: cuánto tomó lo reportado (tarea, tarea agendada o actividad). Con
# caso, el reporte deja además su entrada de tiempo (source: report) para que las
# horas reales del caso lo sumen; task_report_id evita contarlo dos veces.
class AddMinutesToTaskReports < ActiveRecord::Migration[7.0]
  def change
    add_column :task_reports, :minutes, :integer
    add_reference :case_time_entries, :task_report, foreign_key: { on_delete: :nullify }, index: true
  end
end
