# frozen_string_literal: true

# @tickets_cases — Plan-Bandeja-Prioridad F1: duración estimada de la tarea, para
# sumar la carga del día en «Mi día». Opcional (NULL = sin estimar).
class AddEstimatedMinutesToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tasks, :estimated_minutes, :integer
  end
end
