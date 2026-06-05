# frozen_string_literal: true

# @tickets_cases
class CreateCaseEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :case_events do |t|
      t.bigint  :case_ticket_id, null: false
      t.bigint  :account_id,     null: false
      t.bigint  :actor_id

      t.integer :event_type,     null: false
      t.integer :origin,         null: false

      t.jsonb   :payload,        null: false, default: {}

      t.datetime :created_at,   null: false
    end

    add_index :case_events, [:case_ticket_id, :event_type]
    add_index :case_events, [:account_id, :created_at]
    add_index :case_events, :payload, using: :gin
  end
end
