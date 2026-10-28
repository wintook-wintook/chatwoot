# CrmZeus O0 — catálogos de las organizaciones en la base de Wintook, por cuenta
# (account_id): sustituyen a CALIFICACIONES, GIROS, ORIGENES (CRMZeus) y a TIPOS_CLIENTES,
# ZONAS_CLIENTES, COBRADORES, VENDEDORES, CONDICIONES_PAGO, MONEDAS, PAISES, ESTADOS y
# CIUDADES (Microsip).
class CreateCrmCatalogs < ActiveRecord::Migration[7.0]
  def change
    create_lookups
    create_payment_terms
    create_currencies
    create_sellers
    create_geography
  end

  private

  # Catálogos que son solo un nombre: tipo de cliente, calificación, giro, origen, zona, cobrador.
  def create_lookups
    create_table :crm_lookups do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :name, null: false, limit: 100
      t.boolean :is_default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_lookups, 'account_id, kind, lower(name)', unique: true, name: 'index_crm_lookups_unique_name'
  end

  # CONDICIONES_PAGO + PLAZOS_COND_PAG («3 pagos» = 30 % hoy, 35 % a 15 días, 35 % a 30 días).
  def create_payment_terms
    create_table :crm_payment_terms do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.decimal :early_payment_discount_percent, precision: 5, scale: 2, null: false, default: 0
      t.integer :early_payment_days, null: false, default: 0
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_payment_terms, 'account_id, lower(name)', unique: true, name: 'index_crm_payment_terms_unique_name'

    create_table :crm_payment_term_installments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :payment_term, null: false, foreign_key: { to_table: :crm_payment_terms, on_delete: :cascade }
      t.integer :days, null: false, default: 0
      t.decimal :percent, precision: 5, scale: 2, null: false, default: 100
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end

  def create_currencies
    create_table :crm_currencies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 50
      t.string :iso_code, limit: 3
      t.string :symbol, limit: 10
      t.string :amount_in_words, limit: 50
      t.boolean :is_local, null: false, default: false
      t.decimal :fixed_exchange_rate, precision: 14, scale: 6
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_currencies, 'account_id, lower(name)', unique: true, name: 'index_crm_currencies_unique_name'
  end

  # Vendedores: no todos son usuarios de Wintook (en CRMZeus hay «CAJERO», «MOSTRADOR»…).
  def create_sellers
    create_table :crm_sellers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.text :notes
      t.references :user, foreign_key: { on_delete: :nullify }
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_sellers, 'account_id, lower(name)', unique: true, name: 'index_crm_sellers_unique_name'
    add_index :crm_sellers, %i[account_id user_id], unique: true, where: 'user_id IS NOT NULL',
                                                    name: 'index_crm_sellers_unique_user'
  end

  def create_geography
    create_countries
    create_states
    create_cities
  end

  def create_countries
    create_table :crm_countries do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 50
      t.string :abbreviation, limit: 10
      t.string :iso_code, limit: 3
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end
    add_index :crm_countries, 'account_id, lower(name)', unique: true, name: 'index_crm_countries_unique_name'
  end

  def create_states
    create_table :crm_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: { to_table: :crm_countries, on_delete: :cascade }
      t.string :name, null: false, limit: 50
      t.string :abbreviation, limit: 10
      t.timestamps
    end
    add_index :crm_states, 'country_id, lower(name)', unique: true, name: 'index_crm_states_unique_name'
  end

  def create_cities
    create_table :crm_cities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :state, null: false, foreign_key: { to_table: :crm_states, on_delete: :cascade }
      t.string :name, null: false, limit: 50
      t.timestamps
    end
    add_index :crm_cities, 'state_id, lower(name)', unique: true, name: 'index_crm_cities_unique_name'
  end
end
