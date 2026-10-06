# frozen_string_literal: true

# @tickets_cases — integridad referencial de case_tickets.
# Antes: borrar un contacto / conversación / seguimiento dejaba el ticket con
# contact_id / conversation_id / contact_tracking_id colgante (sin FK, sin dependent).
# Política elegida: CONSERVAR el histórico del ticket → on_delete :nullify
# (el ticket sobrevive como registro histórico con la referencia en NULL).
class AddOrphanFksToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    # Índices de una sola columna para que el NULLify en cascada del padre sea eficiente
    # (los índices compuestos existentes arrancan por account_id y no sirven para el borrado).
    add_index :case_tickets, :contact_id,          if_not_exists: true
    add_index :case_tickets, :conversation_id,     if_not_exists: true
    add_index :case_tickets, :contact_tracking_id, if_not_exists: true

    add_foreign_key :case_tickets, :contacts,          column: :contact_id,          on_delete: :nullify, validate: false
    add_foreign_key :case_tickets, :conversations,     column: :conversation_id,     on_delete: :nullify, validate: false
    add_foreign_key :case_tickets, :contact_trackings, column: :contact_tracking_id, on_delete: :nullify, validate: false
  end
end
