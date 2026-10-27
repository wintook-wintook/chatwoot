# Plan-Catalogo-Cotizaciones V1 — cotizaciones (solas o ligadas a una oportunidad,
# un proyecto, una orden o un caso) y sus partidas.
class CreateQuotes < ActiveRecord::Migration[7.0]
  def change
    create_quotes
    create_quote_items
    add_column :case_settings, :quotes_require_opportunity, :boolean, null: false, default: false
    add_column :case_settings, :default_tax_percent, :decimal, precision: 5, scale: 2, null: false, default: 0
  end

  private

  def create_quotes
    create_table :quotes do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :version, null: false, default: 1
      t.references :parent_quote, foreign_key: { to_table: :quotes, on_delete: :nullify }
      t.references :contact, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :opportunity, foreign_key: { to_table: :case_tickets, on_delete: :nullify }
      t.references :origin_ticket, foreign_key: { to_table: :case_tickets, on_delete: :nullify }
      t.integer :status, null: false, default: 0
      t.references :outcome_reason, foreign_key: { to_table: :case_outcome_reasons, on_delete: :nullify }
      t.text :outcome_note
      t.date :postponed_until
      t.string :currency, limit: 3, null: false, default: 'MXN'
      t.decimal :subtotal, precision: 14, scale: 2, null: false, default: 0
      t.decimal :discount_total, precision: 14, scale: 2, null: false, default: 0
      t.decimal :tax_total, precision: 14, scale: 2, null: false, default: 0
      t.decimal :total, precision: 14, scale: 2, null: false, default: 0
      t.date :valid_until
      t.text :terms
      t.text :notes
      t.datetime :sent_at
      t.datetime :viewed_at
      t.datetime :decided_at
      t.string :accepted_by_name
      t.text :accepted_signature
      t.string :public_token, null: false
      t.timestamps
    end
    add_index :quotes, %i[account_id number version], unique: true
    add_index :quotes, :public_token, unique: true
    add_index :quotes, %i[account_id status]
  end

  def create_quote_items
    create_table :quote_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog_item, foreign_key: { on_delete: :nullify }
      t.string :description, null: false
      t.integer :kind
      t.string :unit
      t.decimal :quantity, precision: 12, scale: 2, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 2, null: false, default: 0
      t.decimal :discount_percent, precision: 5, scale: 2, null: false, default: 0
      t.decimal :tax_percent, precision: 5, scale: 2, null: false, default: 0
      t.decimal :total, precision: 14, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
