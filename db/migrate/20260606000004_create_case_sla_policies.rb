# frozen_string_literal: true

# @tickets_cases 2I — Políticas SLA configurables por cuenta (tipo/kind/prioridad).
class CreateCaseSlaPolicies < ActiveRecord::Migration[7.0]
  def change
    create_table :case_sla_policies do |t|
      t.bigint  :account_id,                 null: false
      t.bigint  :case_type_id                          # nullable → aplica a cualquier tipo
      t.integer :ticket_kind                           # nullable → aplica a cualquier naturaleza ITIL
      t.integer :priority,                   null: false
      t.integer :first_response_time_target            # minutos
      t.integer :resolution_time_target                # minutos
      t.boolean :business_hours_only,        null: false, default: false
      t.boolean :active,                     null: false, default: true
      t.timestamps
    end

    add_index :case_sla_policies, [:account_id, :priority]
    add_index :case_sla_policies, [:account_id, :case_type_id, :ticket_kind, :priority],
              unique: true, name: 'index_case_sla_policies_unique_scope'
  end
end
