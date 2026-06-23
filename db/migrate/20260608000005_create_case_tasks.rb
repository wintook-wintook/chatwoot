# frozen_string_literal: true

# @tickets_cases — Tareas / subtareas dentro de un ticket (estilo osTicket "Tasks").
# Checklist de pasos asignables con estado y vencimiento opcional.
class CreateCaseTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :case_tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_ticket, null: false, foreign_key: true
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.string  :title, null: false
      t.integer :status, null: false, default: 0 # pending / done
      t.datetime :due_at
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :case_tasks, [:case_ticket_id, :position]
  end
end
