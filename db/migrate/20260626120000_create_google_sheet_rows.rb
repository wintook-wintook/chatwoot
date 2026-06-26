# @knowledge_sources — Base de Conocimiento / Google Sheets (modo Datos)
# Filas estructuradas de una hoja para consultas analíticas (suma/conteo/filtro).
# Se refrescan al sincronizar; no se vectorizan (los embeddings no resuelven datos exactos).
class CreateGoogleSheetRows < ActiveRecord::Migration[7.0]
  def change
    create_table :google_sheet_rows do |t|
      t.bigint :account_id, null: false
      t.bigint :knowledge_source_id, null: false
      t.integer :row_index, null: false
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end

    add_index :google_sheet_rows, [:knowledge_source_id, :row_index], unique: true,
                                                                       name: 'idx_google_sheet_rows_unique'
    add_index :google_sheet_rows, :account_id
  end
end
