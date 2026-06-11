# frozen_string_literal: true

# @tickets_cases Fase C — tickets internos (agente → agente, sin contacto).
# contact_id pasa a ser opcional; requester_id guarda el agente solicitante.
class AddInternalFieldsToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    change_column_null :case_tickets, :contact_id, true
    add_reference :case_tickets, :requester, foreign_key: { to_table: :users }, null: true
  end
end
