# @tickets_cases P4 — Tareas: descripción + trazabilidad de completado.
# osTicket registra quién y cuándo cerró cada tarea; hasta ahora `status` era
# el único rastro, así que al desmarcar/remarcar se perdía la historia.
class AddCompletionToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tasks, :description,     :text
    add_column :case_tasks, :completed_at,    :datetime
    add_column :case_tasks, :completed_by_id, :bigint

    add_index :case_tasks, :completed_by_id
    add_foreign_key :case_tasks, :users, column: :completed_by_id, on_delete: :nullify
  end
end
