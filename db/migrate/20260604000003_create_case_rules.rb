# frozen_string_literal: true

# @tickets_cases
class CreateCaseRules < ActiveRecord::Migration[7.0]
  def change
    create_table :case_rules do |t|
      t.bigint   :account_id,         null: false
      t.string   :name,               null: false
      t.text     :description
      t.boolean  :active,             null: false, default: true
      t.boolean  :continue_on_match,  null: false, default: false
      t.integer  :position,           null: false, default: 0
      t.jsonb    :conditions,         null: false, default: []
      t.jsonb    :actions,            null: false, default: []

      t.timestamps
    end

    add_index :case_rules, [:account_id, :active, :position]
  end
end
