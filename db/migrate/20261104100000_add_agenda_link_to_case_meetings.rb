# Plan-Agenda A1 — el caso pasa a ser opcional en las tareas agendadas: las que nacen en el
# calendario llevan su contacto (y organización). Con caso, esos datos salen del caso.
class AddAgendaLinkToCaseMeetings < ActiveRecord::Migration[7.0]
  def change
    change_column_null :case_meetings, :case_ticket_id, true
    add_reference :case_meetings, :contact, foreign_key: { on_delete: :cascade }
    add_reference :case_meetings, :organization, foreign_key: { on_delete: :nullify }
  end
end
