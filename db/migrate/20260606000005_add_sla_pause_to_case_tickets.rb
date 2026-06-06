# frozen_string_literal: true

# @tickets_cases 2I — Pausa de SLA en estados de espera.
class AddSlaPauseToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :sla_paused_minutes, :integer,  null: false, default: 0
    add_column :case_tickets, :sla_paused_since,   :datetime
  end
end
