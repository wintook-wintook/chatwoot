# frozen_string_literal: true

# @query_databases — conexión read-only a la BD de un ERP del cliente (Firebird/SQL Server)
class CreateExternalDbConnections < ActiveRecord::Migration[7.0]
  def change
    create_table :external_db_connections do |t|
      t.bigint  :account_id, null: false

      t.string  :name,     null: false
      t.integer :engine,   null: false, default: 0 # firebird: 0, mssql: 1

      t.string  :host,     null: false
      t.integer :port,     null: false
      # Firebird: ruta al archivo .fdb · SQL Server: nombre de la base
      t.string  :database, null: false

      t.string  :username
      t.string  :password

      # opciones del driver: { encrypt: false, tds_version: '7.0', ... }
      t.jsonb   :options, null: false, default: {}

      t.boolean :read_only, null: false, default: true
      t.boolean :active,    null: false, default: true

      t.timestamps
    end

    add_index :external_db_connections, [:account_id, :name], unique: true
  end
end
