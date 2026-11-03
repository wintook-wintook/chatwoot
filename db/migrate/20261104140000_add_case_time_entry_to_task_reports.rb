# Reporte de cierre — la visita de una orden de trabajo también sale en Reportes; la entrada
# de horas guarda su llegada y su ubicación. Las visitas ya terminadas entran de una vez.
class AddCaseTimeEntryToTaskReports < ActiveRecord::Migration[7.0]
  def up
    add_reference :task_reports, :case_time_entry, foreign_key: { on_delete: :nullify }
    TaskReport.reset_column_information
    CaseTimeEntry.visit.where.not(ended_at: nil).includes(:case_ticket, :user).find_each do |entry|
      Field::VisitReport.new(entry.case_ticket, entry, entry.user).record!
    end
  end

  def down
    remove_reference :task_reports, :case_time_entry
  end
end
