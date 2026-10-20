# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Comercial F3: datos de la oportunidad en columnas
# reales (para sumar y ordenar el embudo), resultado separado de `status`,
# catálogo de motivos y moneda por defecto de la cuenta.
class AddCommercialToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    create_table :case_outcome_reasons do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.integer :outcome, null: false # mismo enum que case_tickets.outcome
      t.string  :label, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :case_outcome_reasons, %i[account_id outcome]

    change_table :case_tickets, bulk: true do |t|
      t.decimal  :amount, precision: 14, scale: 2
      t.string   :currency, limit: 3
      t.date     :expected_close_at
      t.integer  :probability
      t.integer  :outcome # won 0, lost 1, cancelled 2 — valores nuevos SIEMPRE al final
      t.datetime :outcome_at
      t.bigint   :outcome_reason_id
      t.text     :outcome_note
      t.date     :postponed_until
    end
    add_index :case_tickets, %i[account_id outcome]
    add_index :case_tickets, :postponed_until, where: 'postponed_until IS NOT NULL'
    add_foreign_key :case_tickets, :case_outcome_reasons, column: :outcome_reason_id, on_delete: :nullify

    change_table :case_type_columns, bulk: true do |t|
      t.integer :outcome     # columna final del embudo (Ganada/Perdida/Cancelada)
      t.integer :probability # % que toma el caso al entrar a la columna
    end

    add_column :case_settings, :default_currency, :string, limit: 3, null: false, default: 'MXN'
  end
end
