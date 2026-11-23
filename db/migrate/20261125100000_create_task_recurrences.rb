# Tareas que se repiten: una tarea fija que Kontrolya le vuelve a crear al responsable cada cierto tiempo.
# mode 'fixed' = fecha fija en el calendario (cada lunes); 'after_done' = N días/semanas/meses después de hacerla.
class CreateTaskRecurrences < ActiveRecord::Migration[7.0]
  def change
    create_recurrences
    add_index :task_recurrences, %i[status next_on]

    add_reference :case_tasks, :task_recurrence, foreign_key: { on_delete: :nullify }
    add_reference :case_meetings, :task_recurrence, foreign_key: { on_delete: :nullify }
  end

  private

  def create_recurrences
    create_table :task_recurrences do |t|
      references(t)
      t.string :title, null: false
      t.text :description
      t.integer :priority, null: false, default: 1
      t.integer :estimated_minutes
      cadence(t)
      t.integer :generated_count, null: false, default: 0
      t.integer :missed_count, null: false, default: 0
      t.date :next_on
      t.date :last_generated_on
      t.string :status, null: false, default: 'active'
      t.timestamps
    end
  end

  def references(table)
    table.references :account, null: false, foreign_key: true
    table.references :user, null: false, foreign_key: true # quién la programó
    table.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
    table.references :contact, foreign_key: { on_delete: :nullify }
    table.references :organization, foreign_key: { on_delete: :nullify }
    table.references :case_ticket, foreign_key: { on_delete: :cascade }
  end

  def cadence(table)
    table.string :mode, null: false, default: 'fixed'
    table.integer :every, null: false, default: 1
    table.string :unit, null: false, default: 'week'
    table.integer :weekdays, array: true, null: false, default: []
    table.string :at_time # HH:MM: con hora sale como tarea agendada
    table.string :time_zone
    table.date :starts_on, null: false
    table.date :ends_on
    table.integer :max_count
  end
end
