# Plan-Contratos R1 — servicios recurrentes de cualquier giro (monitoreo de alarma,
# iguala de soporte, licencia, póliza, membresía…).
#   · contract_types: los da de alta cada empresa, con sus valores por omisión y sus
#     campos propios (custom_fields: [{ key, label, type }]).
#   · contracts: lo que tiene contratado el contacto, cada cuánto se cobra, el plazo y
#     su estado guardado (activo / suspendido / cancelado); «por renovar», «pago
#     vencido» y «terminado» se calculan con las fechas.
class CreateContractTypesAndContracts < ActiveRecord::Migration[7.0]
  def change
    create_contract_types
    create_contracts
  end

  private

  def create_contract_types
    create_table :contract_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: '#2781F6'
      t.integer :default_every, null: false, default: 1
      t.integer :default_unit, null: false, default: 2
      t.integer :default_term_months
      t.boolean :default_auto_renew, null: false, default: true
      t.jsonb :custom_fields, null: false, default: []
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :contract_types, %i[account_id name], unique: true
  end

  def create_contracts
    create_table :contracts do |t|
      contract_links(t)
      contract_terms(t)
      t.timestamps
    end
    add_index :contracts, %i[account_id status next_charge_on]
    add_index :contracts, %i[account_id ends_on]
  end

  def contract_links(table)
    table.references :account, null: false, foreign_key: true
    table.references :contact, null: false, foreign_key: { on_delete: :cascade }
    table.references :contract_type, null: false, foreign_key: true
    table.references :catalog_item, foreign_key: { on_delete: :nullify }
    table.references :customer_asset, foreign_key: { on_delete: :nullify }
    table.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
  end

  def contract_terms(table)
    table.string :title, null: false
    table.decimal :quantity, precision: 12, scale: 2, null: false, default: 1
    table.decimal :price, precision: 14, scale: 2, null: false, default: 0
    table.string :currency, limit: 3, null: false, default: 'MXN'
    table.integer :every, null: false, default: 1
    table.integer :unit, null: false, default: 2
    table.date :starts_on, null: false
    table.date :next_charge_on
    table.date :last_paid_on
    table.integer :term_months
    table.date :ends_on
    table.boolean :auto_renew, null: false, default: true
    table.integer :status, null: false, default: 0
    table.date :cancelled_on
    table.string :cancel_reason
    table.jsonb :custom_attributes, null: false, default: {}
    table.text :notes
  end
end
