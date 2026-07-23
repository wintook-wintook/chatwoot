# @tickets_cases — Reapertura de tickets cerrados (osTicket "Reopen").
# `reopen_count` permite segmentar métricas: un ticket reabierto no debería
# contar dos veces como resuelto.
class AddReopenToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :reopen_count, :integer, default: 0, null: false
    add_column :case_tickets, :reopened_at,  :datetime
  end
end
