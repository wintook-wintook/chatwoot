# frozen_string_literal: true

# @tickets_cases P4 — vencimiento estilo osTicket ("Due Date").
# Fecha límite MANUAL, opcional. Si está presente pisa al vencimiento estimado
# por el SLA (created_at + resolution_time_target); si es NULL, se usa el estimado.
class AddDueAtToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :due_at, :datetime
    add_index  :case_tickets, %i[account_id due_at]
  end
end
