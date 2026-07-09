# frozen_string_literal: true

# @query_databases — consulta predefinida (allowlist) sobre una conexión ERP
class CreateExternalDbQueries < ActiveRecord::Migration[7.0]
  def change
    create_table :external_db_queries do |t|
      t.bigint  :account_id,                null: false
      t.bigint  :external_db_connection_id, null: false

      t.string  :name,         null: false # ej. "facturas_vencidas"
      t.string  :description
      t.text    :sql_template, null: false # SELECT ... WHERE rfc = :rfc

      # params tipados: [{ key:, label:, type:, required: }]
      t.jsonb   :params_schema, null: false, default: []

      t.integer :row_limit,     null: false, default: 200
      t.boolean :ai_enabled,    null: false, default: false # expuesta como tool IA (Modo B)
      t.integer :result_format, null: false, default: 0 # table: 0, summary: 1, template: 2
      t.boolean :active,        null: false, default: true

      t.timestamps
    end

    add_index :external_db_queries, [:external_db_connection_id, :name], unique: true,
                                                                         name: 'index_external_db_queries_on_connection_and_name'
    add_index :external_db_queries, :account_id
  end
end
