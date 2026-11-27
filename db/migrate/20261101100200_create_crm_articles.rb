# CrmZeus A0 — artículos (catalogados y no catalogados) y sus catálogos, en la base de
# Wintook. Sustituyen a ARTICULOS (Microsip = catalogados; base del CRM = no catalogados),
# CLAVES_ARTICULOS, PRECIOS_ARTICULOS, IMPUESTOS_ARTICULOS, LINEAS_ARTICULOS, UNIDADES_VENTA
# e IMPUESTOS. Listas de precios y grupos de líneas van en crm_lookups. Todo por cuenta.
class CreateCrmArticles < ActiveRecord::Migration[7.0]
  def change
    create_article_lines
    create_units
    create_taxes
    create_articles
    create_article_prices
    create_article_taxes
  end

  private

  def create_article_lines
    create_table :crm_article_lines do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 50
      t.string :key, limit: 20
      t.references :group, foreign_key: { to_table: :crm_lookups, on_delete: :nullify }
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_article_lines, 'account_id, lower(name)', unique: true, name: 'index_crm_article_lines_unique_name'
  end

  # UNIDADES_VENTA: en Microsip el artículo guarda el texto; aquí es catálogo con clave SAT opcional.
  def create_units
    create_table :crm_units do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 20
      t.string :sat_key, limit: 3
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_units, 'account_id, lower(name)', unique: true, name: 'index_crm_units_unique_name'
  end

  def create_taxes
    create_table :crm_taxes do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 30
      t.integer :tax_type, null: false, default: 1
      t.decimal :percent, precision: 9, scale: 6, null: false, default: 0
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_taxes, 'account_id, lower(name)', unique: true, name: 'index_crm_taxes_unique_name'
  end

  def create_articles
    create_table :crm_articles do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :catalog_status, null: false, default: 2 # como ES_CATALOGADO: 1 catalogado, 2 no catalogado
      t.string :key, limit: 20
      t.string :name, null: false, limit: 200
      t.string :normalized_name, null: false, limit: 200 # sin acentos ni mayúsculas: no se repite (como CRMZeus)
      t.references :line, foreign_key: { to_table: :crm_article_lines, on_delete: :nullify }
      t.references :unit, foreign_key: { to_table: :crm_units, on_delete: :nullify }
      t.string :status, limit: 1, null: false, default: 'A'
      t.boolean :is_stockable, null: false, default: true
      add_article_detail_columns(t)
      t.timestamps
    end
    add_index :crm_articles, %i[account_id catalog_status]
    add_index :crm_articles, %i[account_id normalized_name], unique: true, name: 'index_crm_articles_unique_name'
    add_index :crm_articles, 'account_id, lower(key)', unique: true, where: 'key IS NOT NULL',
                                                       name: 'index_crm_articles_unique_key'
  end

  # Pestaña «Otros» de CRMZeus + auditoría.
  def add_article_detail_columns(table)
    table.string :purchase_unit, limit: 20
    table.decimal :purchase_unit_content, precision: 18, scale: 5, null: false, default: 1
    table.decimal :unit_weight, precision: 18, scale: 5, null: false, default: 0
    table.text :notes
    table.datetime :cataloged_at
    table.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
    table.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
  end

  # PRECIOS_ARTICULOS: un precio por lista de precios, cada uno en su moneda.
  def create_article_prices
    create_table :crm_article_prices do |t|
      t.references :account, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: { to_table: :crm_articles, on_delete: :cascade }
      t.references :price_list, null: false, foreign_key: { to_table: :crm_lookups, on_delete: :cascade }
      t.decimal :price, precision: 18, scale: 6, null: false, default: 0
      t.references :currency, foreign_key: { to_table: :crm_currencies, on_delete: :nullify }
      t.timestamps
    end
    add_index :crm_article_prices, %i[article_id price_list_id], unique: true
  end

  # IMPUESTOS_ARTICULOS: un artículo puede llevar varios (IVA + retenciones).
  def create_article_taxes
    create_table :crm_article_taxes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: { to_table: :crm_articles, on_delete: :cascade }
      t.references :tax, null: false, foreign_key: { to_table: :crm_taxes, on_delete: :cascade }
      t.timestamps
    end
    add_index :crm_article_taxes, %i[article_id tax_id], unique: true
  end
end
