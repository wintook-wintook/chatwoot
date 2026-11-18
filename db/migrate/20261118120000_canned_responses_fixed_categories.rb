# frozen_string_literal: true

# proyecto@predefinidas_que_contestan — la categoría de una respuesta predefinida ya no la
# inventa cada cuenta: son tres fijas (general, ficha, objecion; columna `kind`) y la búsqueda
# de los agentes las usa. Las categorías libres se quitan; todas quedan en General y cada
# cuenta las cambia a Ficha u Objeción (a mano o con lo que diga el auditor).
class CannedResponsesFixedCategories < ActiveRecord::Migration[7.0]
  def up
    add_column :canned_responses, :kind, :string, null: false, default: 'general'
    execute <<~SQL.squish
      UPDATE knowledge_items SET metadata = (COALESCE(metadata, '{}'::jsonb) - 'category') || '{"kind": "general"}'::jsonb
      WHERE source_type = 'canned_response'
    SQL
    remove_reference :canned_responses, :category, foreign_key: { to_table: :canned_response_categories, on_delete: :nullify },
                                                   index: true
    drop_table :canned_response_categories
  end

  # La estructura vuelve; las categorías que había, no.
  def down
    create_table :canned_response_categories do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :description
      t.timestamps
    end
    add_index :canned_response_categories, 'account_id, lower((name)::text)', unique: true,
                                                                              name: 'index_canned_categories_on_account_and_lower_name'
    add_reference :canned_responses, :category, foreign_key: { to_table: :canned_response_categories, on_delete: :nullify },
                                                index: true
    execute "UPDATE knowledge_items SET metadata = metadata - 'kind' WHERE source_type = 'canned_response'"
    remove_column :canned_responses, :kind
  end
end
