# frozen_string_literal: true

# @tickets_cases — Plan-Bandeja-Prioridad F2: «Programada para» y el orden propio
# de «Mi día». `planned_on` = el día en que el agente piensa hacer la tarea
# (distinto del vencimiento); las de hoy forman su orden del día, en la posición
# `focus_position`. `focused_at`: cuándo entró al plan (para avisar de las
# urgentes que llegan después).
class AddMyDayPlanToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    change_table :case_tasks, bulk: true do |t|
      t.date :planned_on
      t.integer :focus_position
      t.datetime :focused_at
    end
    add_index :case_tasks, %i[assignee_id planned_on]
  end
end
