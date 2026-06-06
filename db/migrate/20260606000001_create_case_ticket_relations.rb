# frozen_string_literal: true

# @tickets_cases 2E — Relaciones entre tickets (duplicado, padre/hijo, incidente↔problema, etc.).
class CreateCaseTicketRelations < ActiveRecord::Migration[7.0]
  def change
    create_table :case_ticket_relations do |t|
      t.bigint  :account_id,        null: false
      t.bigint  :ticket_id,         null: false
      t.bigint  :related_ticket_id, null: false
      t.integer :relation_type,     null: false, default: 0
      t.timestamps
    end

    add_index :case_ticket_relations, :account_id
    add_index :case_ticket_relations, :related_ticket_id
    add_index :case_ticket_relations,
              %i[ticket_id related_ticket_id relation_type],
              unique: true,
              name: 'index_case_ticket_relations_unique'
  end
end
