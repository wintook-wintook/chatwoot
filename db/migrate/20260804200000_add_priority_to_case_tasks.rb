# frozen_string_literal: true

# @tickets_cases — prioridad PROPIA de la tarea, independiente de la del ticket.
# Una tarea urgente puede colgar de un ticket de prioridad baja y al revés: no se
# hereda ni se deriva, se captura al dar de alta la tarea.
#
# Default 1 (media), igual que case_tickets.priority, para que las tareas que ya
# existen queden en un valor neutro en vez de nulo.
class AddPriorityToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tasks, :priority, :integer, default: 1, null: false

    # La bandeja de tareas filtra y ordena por cuenta; el índice acompaña ese
    # acceso para cuando se sume el filtro por prioridad.
    add_index :case_tasks, %i[account_id priority]
  end
end
