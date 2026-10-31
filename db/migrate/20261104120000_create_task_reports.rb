# Reporte de cierre — qué se hizo al concluir una tarea o tarea agendada, con su resultado
# (catálogo por cuenta) y su evidencia. Guarda el cliente y el título del momento: el
# reporte sobrevive aunque la tarea se borre, y reabrirla no lo toca.
class CreateTaskReports < ActiveRecord::Migration[7.0]
  def change
    create_table :task_outcomes do |t|
      t.references :account, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :task_reports do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_task, foreign_key: { on_delete: :nullify }
      t.references :case_meeting, foreign_key: { on_delete: :nullify }
      t.references :case_ticket, foreign_key: { on_delete: :nullify }
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.references :organization, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :task_outcome, foreign_key: { on_delete: :nullify }
      t.string :outcome_label
      t.string :title, null: false
      t.text :content, null: false
      t.datetime :closed_at
      t.timestamps
    end
    add_index :task_reports, [:account_id, :closed_at]
  end
end
