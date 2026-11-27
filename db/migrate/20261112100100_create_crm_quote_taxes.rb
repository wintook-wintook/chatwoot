# CrmZeus Q3.1 — impuestos del documento (IMPUESTOS_DCDOCTOS_PDV): un renglón por impuesto con lo
# acumulado de sus partidas, como addTaxes de CRMZeus. Y en los impuestos de cada partida
# (IMPUESTOS_DCDOCTOS_PDV_DET) la venta y el impuesto brutos (antes del descuento de la partida).
# Los dos los escribe Crm::QuoteTotals en cada guardado.
class CreateCrmQuoteTaxes < ActiveRecord::Migration[7.0]
  def change
    change_table :crm_quote_item_taxes, bulk: true do |t|
      t.decimal :gross_base_amount, precision: 15, scale: 2, null: false, default: 0 # VENTA_BRUTA
      t.decimal :gross_amount, precision: 18, scale: 6, null: false, default: 0 # IMPORTE_IMPUESTO_BRUTO
    end

    create_table :crm_quote_taxes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: { to_table: :crm_quotes, on_delete: :cascade }
      t.references :tax, foreign_key: { to_table: :crm_taxes, on_delete: :nullify }
      # Copiados de la partida, como en crm_quote_item_taxes.
      t.string :name, null: false, limit: 30
      t.integer :tax_type, null: false
      t.decimal :percent, precision: 9, scale: 6, null: false, default: 0 # PCTJE_IMPUESTO
      t.decimal :base_amount, precision: 15, scale: 2, null: false, default: 0 # VENTA_NETA
      t.decimal :gross_base_amount, precision: 15, scale: 2, null: false, default: 0 # VENTA_BRUTA
      t.decimal :amount, precision: 18, scale: 6, null: false, default: 0 # IMPORTE_IMPUESTO
      t.decimal :gross_amount, precision: 18, scale: 6, null: false, default: 0 # IMPORTE_IMPUESTO_BRUTO
      t.integer :position, null: false, default: 0 # el orden en que aparece en las partidas
      t.timestamps
    end
    add_index :crm_quote_taxes, %i[quote_id tax_id], unique: true
  end
end
