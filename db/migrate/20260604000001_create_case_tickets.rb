# frozen_string_literal: true

# @tickets_cases
class CreateCaseTickets < ActiveRecord::Migration[7.0]
  def change
    create_table :case_tickets do |t|
      t.bigint  :account_id,           null: false
      t.bigint  :contact_id,           null: false
      t.bigint  :conversation_id
      t.bigint  :contact_tracking_id
      t.bigint  :assignee_id
      t.bigint  :team_id

      t.integer :case_type,            null: false, default: 0
      t.integer :origin,               null: false, default: 0
      t.integer :priority,             null: false, default: 1
      t.integer :status,               null: false, default: 0
      t.integer :assignee_type,        null: false, default: 0
      t.integer :sla_status,           null: false, default: 0

      t.string  :title,                null: false
      t.text    :description

      t.integer :first_response_time_target
      t.integer :resolution_time_target
      t.datetime :first_response_at
      t.datetime :resolved_at
      t.datetime :closed_at

      t.jsonb   :metadata,             null: false, default: {}
      t.jsonb   :custom_attributes,    null: false, default: {}

      t.timestamps
    end

    add_index :case_tickets, [:account_id, :status]
    add_index :case_tickets, [:account_id, :contact_id]
    add_index :case_tickets, [:account_id, :sla_status]
    add_index :case_tickets, [:account_id, :case_type]
    add_index :case_tickets, :metadata, using: :gin
  end
end
