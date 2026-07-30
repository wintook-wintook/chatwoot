# frozen_string_literal: true

# @tickets_cases — Bloqueo de ticket (osTicket lock): evita que dos agentes
# trabajen el mismo ticket a la vez. Bloqueo suave con expiración por tiempo.
class AddLockToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_tickets, :locked_by, null: true, foreign_key: { to_table: :users }
    add_column :case_tickets, :locked_at, :datetime
  end
end
