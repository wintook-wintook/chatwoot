# frozen_string_literal: true

# @query_databases — bot cobrador (Modo A: recordatorio proactivo + flag Modo B).
class CreateErpCollectionBots < ActiveRecord::Migration[7.0]
  def change
    create_table :erp_collection_bots do |t|
      t.bigint  :account_id,                null: false
      t.bigint  :external_db_connection_id, null: false
      t.bigint  :external_db_query_id # consulta "por vencer / vencidas" (Modo A)
      t.bigint  :inbox_id             # canal de entrega del recordatorio

      t.string  :name,            null: false
      t.text    :message_template # plantilla con {{columna}} de la fila del resultado
      t.string  :phone_column,    null: false, default: 'TELEFONO' # columna con el teléfono

      t.integer :run_hour,        null: false, default: 8 # hora (0-23) del recordatorio diario
      t.boolean :mode_b_enabled,  null: false, default: false # Modo B (consulta IA por chat)
      t.boolean :active,          null: false, default: true
      t.datetime :last_run_at

      t.timestamps
    end

    add_index :erp_collection_bots, :account_id
  end
end
