# Plan-Catalogo-Cotizaciones C1 — catálogo único de productos, servicios y
# refacciones (lo usan las cotizaciones de Ventas y los materiales de las órdenes).
class CreateCatalogItems < ActiveRecord::Migration[7.0]
  def change
    create_table :catalog_items do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku
      t.integer :kind, null: false, default: 0
      t.string :category
      t.string :unit
      t.decimal :price, precision: 14, scale: 2, null: false, default: 0
      t.string :currency, limit: 3, null: false, default: 'MXN'
      t.decimal :cost, precision: 14, scale: 2
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :catalog_items, %i[account_id sku], unique: true, where: 'sku IS NOT NULL'
    add_index :catalog_items, %i[account_id active kind]
  end
end
