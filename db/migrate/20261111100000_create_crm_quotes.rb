# CrmZeus Q0 — cotizaciones en la base de Wintook. Sustituyen a DCDOCTOS_PDV (encabezado),
# DCDOCTOS_PDV_DET (partidas; los kits ligan sus componentes con parent_item, en vez de
# SUB_MOVTOS_PDV), IMPUESTOS_DCDOCTOS_PDV_DET (impuestos de cada partida) y CTFOLIOS_USUARIOS
# (serie y consecutivo de cada agente). Los totales los calcula y guarda el servidor. Todo por cuenta.
class CreateCrmQuotes < ActiveRecord::Migration[7.0]
  def change
    create_quote_series
    create_quotes
    create_quote_items
    create_quote_item_taxes
  end

  private

  # CTFOLIOS_USUARIOS (TIPO_DOCTO 'cot'): una serie por agente; el folio es la serie + el consecutivo
  # rellenado con ceros a 9 caracteres (F_Folio de CRMZeus).
  def create_quote_series
    create_table :crm_quote_series do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :series, null: false, limit: 8
      t.integer :last_number, null: false, default: 0
      t.timestamps
    end
    add_index :crm_quote_series, %i[account_id user_id], unique: true
    add_index :crm_quote_series, 'account_id, upper(series)', unique: true, name: 'index_crm_quote_series_unique_series'
  end

  def create_quotes
    create_table :crm_quotes do |t|
      t.references :account, null: false, foreign_key: true
      add_quote_header_columns(t)
      add_quote_fiscal_columns(t)
      add_quote_amount_columns(t)
      add_quote_audit_columns(t)
      t.timestamps
    end
    add_index :crm_quotes, %i[account_id folio], unique: true
    add_index :crm_quotes, %i[account_id status quote_date]
  end

  def add_quote_header_columns(table)
    table.string :series, null: false, limit: 8
    table.integer :number, null: false
    table.string :folio, null: false, limit: 20
    table.string :status, null: false, limit: 1, default: 'N' # ESTATUS: N pendiente, E ganada, P perdida, C cancelada
    table.references :organization, null: false, foreign_key: { to_table: :crm_organizations }
    table.references :contact, type: :integer, foreign_key: { on_delete: :nullify }
    table.references :shipping_address, foreign_key: { to_table: :crm_organization_addresses, on_delete: :nullify }
    table.references :seller, foreign_key: { to_table: :crm_sellers, on_delete: :nullify }
    table.references :currency, foreign_key: { to_table: :crm_currencies, on_delete: :nullify }
    table.references :payment_term, foreign_key: { to_table: :crm_payment_terms, on_delete: :nullify }
    table.decimal :exchange_rate, precision: 18, scale: 6, null: false, default: 1
    table.date :quote_date, null: false
    table.date :valid_until
    table.date :delivery_date
  end

  # «Otros datos» de CRMZeus y observaciones de encabezado y pie.
  def add_quote_fiscal_columns(table)
    table.string :cfdi_use, limit: 4
    table.string :sat_payment_method, limit: 3 # PUE de contado, PPD a plazos (sale de la condición de pago)
    table.string :purchase_order, limit: 35
    table.date :purchase_order_date
    table.text :header_notes
    table.text :footer_notes
  end

  # Descuento extra (TIPO_DSCTO P por porcentaje / I por importe), cargos y totales.
  def add_quote_amount_columns(table)
    table.string :extra_discount_type, null: false, limit: 1, default: 'P'
    table.decimal :extra_discount_value, precision: 15, scale: 6, null: false, default: 0
    table.decimal :extra_discount_percent, precision: 9, scale: 6, null: false, default: 0
    table.decimal :extra_discount_amount, precision: 15, scale: 2, null: false, default: 0
    table.decimal :freight, precision: 15, scale: 2, null: false, default: 0
    table.decimal :other_charges, precision: 15, scale: 2, null: false, default: 0
    %i[subtotal discount_total net_amount tax_total withholding_total total].each do |column|
      table.decimal column, precision: 15, scale: 2, null: false, default: 0
    end
  end

  def add_quote_audit_columns(table)
    table.datetime :status_changed_at
    table.references :status_changed_by, foreign_key: { to_table: :users, on_delete: :nullify }
    table.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
    table.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
  end

  def create_quote_items
    create_table :crm_quote_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: { to_table: :crm_quotes, on_delete: :cascade }
      t.references :parent_item, foreign_key: { to_table: :crm_quote_items, on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.string :role, null: false, limit: 1, default: 'N' # ROL: N normal, J kit, C componente de kit
      add_item_article_columns(t)
      add_item_amount_columns(t)
      t.text :notes
      t.text :extra_notes
      t.timestamps
    end
  end

  # Se copia lo del artículo al cotizar: la cotización no cambia si después cambia el artículo.
  def add_item_article_columns(table)
    table.references :article, foreign_key: { to_table: :crm_articles, on_delete: :nullify }
    table.string :key, limit: 20
    table.string :description, null: false, limit: 200
    table.string :unit, limit: 20
    table.references :price_list, foreign_key: { to_table: :crm_lookups, on_delete: :nullify }
  end

  def add_item_amount_columns(table)
    table.decimal :quantity, precision: 18, scale: 5, null: false, default: 1
    table.decimal :unit_price, precision: 18, scale: 6, null: false, default: 0
    table.decimal :discount_percent, precision: 9, scale: 6, null: false, default: 0
    %i[gross_amount discount_amount net_amount].each do |column|
      table.decimal column, precision: 15, scale: 2, null: false, default: 0
    end
    table.decimal :tax_amount, precision: 18, scale: 6, null: false, default: 0
    table.decimal :withholding_amount, precision: 18, scale: 6, null: false, default: 0
  end

  # Nombre, tipo y % se copian: la cotización no cambia si después cambia el impuesto.
  def create_quote_item_taxes
    create_table :crm_quote_item_taxes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: { to_table: :crm_quote_items, on_delete: :cascade }
      t.references :tax, foreign_key: { to_table: :crm_taxes, on_delete: :nullify }
      t.string :name, null: false, limit: 30
      t.integer :tax_type, null: false
      t.decimal :percent, precision: 9, scale: 6, null: false, default: 0
      t.decimal :base_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 18, scale: 6, null: false, default: 0
      t.timestamps
    end
    add_index :crm_quote_item_taxes, %i[item_id tax_id], unique: true
  end
end
