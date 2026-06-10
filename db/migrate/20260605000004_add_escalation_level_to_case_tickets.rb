# frozen_string_literal: true

# @tickets_cases 2D — Nivel de escalamiento (0 = N1, 1 = N2, 2 = N3).
class AddEscalationLevelToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :escalation_level, :integer, null: false, default: 0
  end
end
