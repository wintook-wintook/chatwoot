# frozen_string_literal: true

# @tickets_cases
class CreateCaseTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :case_types do |t|
      t.bigint  :account_id, null: false
      t.string  :name,       null: false
      t.string  :color,      null: false, default: '#3b82f6'
      t.integer :position,   null: false, default: 0
      t.timestamps
    end

    add_index :case_types, [:account_id, :position]
  end
end
