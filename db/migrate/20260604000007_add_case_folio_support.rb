# frozen_string_literal: true

# @tickets_cases — sistema de folios configurable
class AddCaseFolioSupport < ActiveRecord::Migration[7.0]
  def change
    # Prefijo por tipo de caso (ej. "SOP" para Soporte) — usado por el token {PREFIX}
    add_column :case_types, :prefix, :string, null: false, default: ''

    # Folio asignado al ticket (inmutable). Único por cuenta.
    add_column :case_tickets, :folio, :string
    add_index  :case_tickets, [:account_id, :folio], unique: true,
               where: 'folio IS NOT NULL', name: 'index_case_tickets_on_account_and_folio'

    # Contadores atómicos por cuenta + llave de alcance (type:id, período, etc.)
    create_table :case_folio_counters do |t|
      t.bigint  :account_id,  null: false
      t.string  :counter_key, null: false
      t.integer :value,       null: false, default: 0
      t.timestamps
    end
    add_index :case_folio_counters, [:account_id, :counter_key], unique: true

    # Configuración de folio por cuenta (una fila por cuenta)
    create_table :case_folio_configs do |t|
      t.bigint  :account_id,   null: false
      t.boolean :enabled,      null: false, default: true
      t.string  :template,     null: false, default: '{PREFIX}-{SEQ:5}'
      t.boolean :per_type,     null: false, default: true
      t.string  :reset_period, null: false, default: 'never' # never | daily | monthly | yearly
      t.timestamps
    end
    add_index :case_folio_configs, :account_id, unique: true
  end
end
