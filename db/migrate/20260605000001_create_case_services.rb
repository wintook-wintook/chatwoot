# frozen_string_literal: true

# @tickets_cases 2B — Servicio afectado (configurable por cuenta).
class CreateCaseServices < ActiveRecord::Migration[7.0]
  def change
    create_table :case_services do |t|
      t.bigint  :account_id, null: false
      t.string  :name,       null: false
      t.string  :color,      null: false, default: '#64748b'
      t.boolean :active,     null: false, default: true
      t.integer :position,   null: false, default: 0
      t.timestamps
    end

    add_index :case_services, [:account_id, :position]
  end
end
