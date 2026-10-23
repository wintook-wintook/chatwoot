# @tickets_cases — Plan-Plantilla-Tareas-Etapa T2: la tarea que nació de la plantilla
# de una etapa recuerda de cuál (para no duplicarla si el caso regresa a la etapa),
# en qué etapa nació, si es obligatoria para avanzar y, si la plantilla la dio a un
# equipo, a cuál.
class AddStageTemplateToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_tasks, :case_type_column_task, foreign_key: { on_delete: :nullify }, index: false
    add_reference :case_tasks, :case_type_column, foreign_key: { on_delete: :nullify }, index: false
    add_column :case_tasks, :required, :boolean, null: false, default: false
    add_column :case_tasks, :team_id, :bigint
    add_index :case_tasks, %i[case_ticket_id case_type_column_task_id], name: 'index_case_tasks_on_ticket_and_template'
  end
end
