# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Proyecto P2: un hito de proyecto es una tarea marcada
# (decisión 4). Cuenta para el avance automático del proyecto junto con sus casos hijos.
class AddMilestoneToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tasks, :milestone, :boolean, null: false, default: false
  end
end
