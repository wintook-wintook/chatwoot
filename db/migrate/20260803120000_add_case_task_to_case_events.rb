# frozen_string_literal: true

# @tickets_cases — una nota interna (case_events con event_type :internal_note)
# puede pertenecer al ticket (case_task_id NULL, como hasta ahora) o a una tarea
# concreta del mismo ticket (case_task_id apuntando a case_tasks). Al borrar la
# tarea la nota NO se pierde: vuelve a ser del ticket (:nullify).
class AddCaseTaskToCaseEvents < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_events, :case_task,
                  null: true,
                  index: true,
                  foreign_key: { on_delete: :nullify }
  end
end
