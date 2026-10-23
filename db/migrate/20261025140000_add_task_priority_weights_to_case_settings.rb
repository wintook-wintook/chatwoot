# frozen_string_literal: true

# @tickets_cases — Plan-Bandeja-Prioridad F3: pesos del puntaje de «Mi día» por
# cuenta. Solo se guardan los que la cuenta cambió; el resto sale de
# Cases::TaskPriorityScore::DEFAULT_WEIGHTS ({} = todo por defecto).
class AddTaskPriorityWeightsToCaseSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :case_settings, :task_priority_weights, :jsonb, null: false, default: {}
  end
end
