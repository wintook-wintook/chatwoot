# Presupuesto de ventas: metas mensuales con dimensiones opcionales. Un renglón por
# combinación y mes: global (sin dimensiones), vendedor, cliente (organización o
# contacto), línea de producto, producto y sus cruces. Etapa 1 usa vendedor y
# vendedor + cliente; línea, producto y unidades quedan listos para después.
class CreateSalesBudgetLines < ActiveRecord::Migration[7.0]
  def change # rubocop:disable Metrics/MethodLength
    create_table :sales_budget_lines do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :period, null: false
      t.string :currency, limit: 3, null: false, default: 'MXN'
      t.decimal :amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :quantity, precision: 12, scale: 2
      t.references :user, foreign_key: { on_delete: :cascade }, index: false
      t.references :organization, foreign_key: { on_delete: :cascade }
      t.references :contact, foreign_key: { on_delete: :cascade }
      t.bigint :product_line_id # su tabla y FK llegan con las líneas de producto
      t.references :catalog_item, foreign_key: { on_delete: :cascade }
      t.string :note
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.timestamps
    end

    add_index :sales_budget_lines, [:account_id, :period]
    add_index :sales_budget_lines, [:account_id, :user_id, :period]
    add_index :sales_budget_lines, :product_line_id
    add_index :sales_budget_lines,
              'account_id, period, currency, COALESCE(user_id, 0), COALESCE(organization_id, 0), COALESCE(contact_id, 0), ' \
              'COALESCE(product_line_id, 0), COALESCE(catalog_item_id, 0)',
              unique: true, name: 'index_sales_budget_lines_unique_dimensions'
  end
end
