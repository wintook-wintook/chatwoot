# frozen_string_literal: true

# @tickets_cases
class AddCaseTypeIdToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :case_type_id, :bigint
    add_index  :case_tickets, [:account_id, :case_type_id]
  end
end
