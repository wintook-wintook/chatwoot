# Productos y servicios › Parámetros: categorías (con subcategorías), impuestos y unidades de medida como listas
# de la cuenta. El producto guarda a cuál pertenece; las columnas de texto category/unit se quedan como copia
# para lo que ya las lee (cotizaciones, órdenes, agentes). Lo que ya estaba escrito se convierte la primera vez
# que se abre el catálogo (CatalogParameters.ensure!).
#
# Impuestos: trasladados (IVA) y retenciones (ISR, IVA retenido). La cotización guarda en cada partida el impuesto
# elegido y sus retenciones (copia con nombre y porcentaje), y aplica las retenciones solo si el cliente es persona
# moral (apply_withholdings).
#
# Formatos de cotización: la empresa diseña varios (bloques, marca, textos) y escoge uno por cotización; los datos
# de la empresa (razón social, RFC, dirección…) van una sola vez en case_settings.company_profile.
class CreateCatalogParameters < ActiveRecord::Migration[7.0]
  def change
    create_categories
    create_units
    create_tax_rates
    add_quote_withholdings
    create_quote_formats
    change_table :catalog_items, bulk: true do |t|
      t.references :catalog_category, foreign_key: true
      t.references :catalog_unit, foreign_key: true
      t.references :tax_rate, foreign_key: true
      t.boolean :price_includes_tax, null: false, default: false
      t.string :sat_code
      t.bigint :withholding_rate_ids, array: true, null: false, default: []
    end
  end

  private

  def create_categories
    create_table :catalog_categories do |t|
      t.references :account, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :catalog_categories }
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_units
    create_table :catalog_units do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.string :sat_code
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_tax_rates
    create_table :tax_rates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.decimal :percent, precision: 7, scale: 4, null: false, default: 0
      t.boolean :exempt, null: false, default: false
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def add_quote_withholdings
    change_table :quote_items, bulk: true do |t|
      t.bigint :tax_rate_id
      t.jsonb :withholdings, null: false, default: []
    end
    change_table :quotes, bulk: true do |t|
      t.boolean :apply_withholdings, null: false, default: false
      t.decimal :withholding_total, precision: 14, scale: 2, null: false, default: 0
    end
  end

  def create_quote_formats
    create_table :quote_formats do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end
    add_reference :quotes, :quote_format, foreign_key: { on_delete: :nullify }
    add_column :case_settings, :company_profile, :jsonb, null: false, default: {}
  end
end
