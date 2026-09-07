# frozen_string_literal: true

# @tickets_cases — solicitante de la tarea (quién la pidió). A diferencia del
# responsable (assignee, editable), el solicitante se fija al crear la tarea con
# el agente actual y no se cambia desde la UI: es la firma de "quién la abrió".
# ON DELETE nullify para que borrar al usuario no arrastre la tarea.
class AddRequesterToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_tasks, :requester, null: true, index: true,
                                           foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
