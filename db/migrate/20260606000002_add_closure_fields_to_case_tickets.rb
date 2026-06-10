# frozen_string_literal: true

# @tickets_cases 2G — Cierre documentado obligatorio.
class AddClosureFieldsToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :closure_type,        :integer
    add_column :case_tickets, :closure_cause,       :text
    add_column :case_tickets, :closure_solution,    :text
    add_column :case_tickets, :customer_confirmed,  :boolean, null: false, default: false
  end
end
