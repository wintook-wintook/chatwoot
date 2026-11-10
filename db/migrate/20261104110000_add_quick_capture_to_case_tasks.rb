# Plan-Agenda — tarea de captura rápida: el caso es opcional, y sin caso puede llevar
# contacto u organización, o nada (entonces solo se ve en Mi día del responsable).
class AddQuickCaptureToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    change_column_null :case_tasks, :case_ticket_id, true
    add_reference :case_tasks, :contact, foreign_key: { on_delete: :cascade }
    add_reference :case_tasks, :organization, foreign_key: { on_delete: :nullify }
  end
end
