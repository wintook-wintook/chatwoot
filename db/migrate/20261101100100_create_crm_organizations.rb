# CrmZeus O0 — organizaciones (clientes y prospectos) y sus direcciones, en la base de
# Wintook. Sustituyen a CLIENTES / PROSPECTOS / CLIENTES_COMPLEMENTOS / DIRS_CLIENTES de
# CRMZeus y Microsip. Todo va por cuenta (account_id).
class CreateCrmOrganizations < ActiveRecord::Migration[7.0]
  def change
    create_organizations
    create_organization_addresses
  end

  private

  def create_organizations
    create_table :crm_organizations do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :organization_type, null: false, default: 2 # mismos valores que TIPO_ORGANIZACION_ID: 1 cliente, 2 prospecto
      t.string :key, limit: 20
      t.string :legal_name, null: false, limit: 100
      t.string :trade_name, null: false, limit: 100
      t.string :phone, limit: 35
      t.string :email
      t.string :tax_id, limit: 18
      add_organization_references(t)
      add_organization_admin_columns(t)
      t.text :notes
      t.datetime :converted_at
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_organization_indexes
  end

  def add_organization_indexes
    add_index :crm_organizations, %i[account_id organization_type]
    add_index :crm_organizations, 'account_id, lower(legal_name)', unique: true, name: 'index_crm_organizations_unique_legal_name'
    add_index :crm_organizations, 'account_id, lower(trade_name)', unique: true, name: 'index_crm_organizations_unique_trade_name'
    add_index :crm_organizations, 'account_id, lower(key)', unique: true, where: 'key IS NOT NULL',
                                                            name: 'index_crm_organizations_unique_key'
  end

  # Pestaña «Administración» de CRMZeus. status = letras de ESTATUS de Microsip (A, C, V, M, B).
  def add_organization_admin_columns(table)
    table.boolean :respect_seller, null: false, default: false
    table.decimal :credit_limit, precision: 14, scale: 2, null: false, default: 0
    table.string :status, limit: 1, null: false, default: 'A'
    table.date :suspended_on
    table.string :suspension_reason, limit: 250
    table.boolean :charge_taxes, null: false, default: true
    table.boolean :withholds_taxes, null: false, default: false
    table.string :cfdi_use, limit: 4
    table.string :sat_payment_form, limit: 3
    table.string :invoice_email
  end

  def add_organization_references(table)
    %i[customer_type rating industry origin zone collector].each do |name|
      table.references name, foreign_key: { to_table: :crm_lookups, on_delete: :nullify }
    end
    table.references :seller, foreign_key: { to_table: :crm_sellers, on_delete: :nullify }
    table.references :payment_term, foreign_key: { to_table: :crm_payment_terms, on_delete: :nullify }
    table.references :currency, foreign_key: { to_table: :crm_currencies, on_delete: :nullify }
  end

  # DIRS_CLIENTES: la principal es el domicilio de la organización (pestaña «Dirección»);
  # las demás son consignatarios, que las cotizaciones eligen. Una sola «para facturar».
  def create_organization_addresses
    create_table :crm_organization_addresses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: { to_table: :crm_organizations, on_delete: :cascade }
      t.string :consignee_name, null: false, limit: 100
      add_address_columns(t)
      t.string :tax_id, limit: 18
      t.string :phone, limit: 35
      t.string :phone2, limit: 35
      t.string :email
      t.string :contact_name, limit: 100
      t.boolean :is_primary, null: false, default: false
      t.boolean :for_billing, null: false, default: false
      t.timestamps
    end
    add_index :crm_organization_addresses, :organization_id, unique: true, where: 'is_primary',
                                                             name: 'index_crm_organization_addresses_one_primary'
    add_index :crm_organization_addresses, :organization_id, unique: true, where: 'for_billing',
                                                             name: 'index_crm_organization_addresses_one_billing'
  end

  def add_address_columns(table)
    table.string :street, limit: 100
    table.string :exterior_number, limit: 10
    table.string :interior_number, limit: 10
    table.string :neighborhood, limit: 100
    table.string :town, limit: 100
    table.string :reference, limit: 100
    table.references :city, foreign_key: { to_table: :crm_cities, on_delete: :nullify }
    table.string :postal_code, limit: 10
  end
end
