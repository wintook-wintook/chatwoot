# @tickets_cases — Plan-Plantilla-Tareas-Etapa T1: tareas plantilla de cada etapa
# (columna) de un tipo de caso. Al entrar a la etapa se crean como tareas del caso
# (T2); las obligatorias deciden cuándo se sugiere pasar a la siguiente (T3).
class CreateCaseTypeColumnTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :case_type_column_tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_type_column, null: false, foreign_key: { on_delete: :cascade }
      t.string  :title, null: false
      t.text    :description
      t.boolean :required, null: false, default: true
      t.integer :due_after_hours
      t.integer :priority, null: false, default: 1
      t.integer :estimated_minutes
      t.integer :assignee_mode, null: false, default: 0
      t.bigint  :assignee_id
      t.bigint  :team_id
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :case_type_column_tasks, %i[case_type_column_id position], name: 'index_column_tasks_on_column_and_position'
  end
end
