# @knowledge_sources
# Tabla de fuentes de conocimiento configuradas por cuenta.
# source_type: 'canned_response' | 'discourse'
# config (jsonb): configuración específica por tipo (url, api_key, etc.)
class CreateKnowledgeSources < ActiveRecord::Migration[6.1]
  def change
    create_table :knowledge_sources do |t|
      t.references :account, null: false, foreign_key: true
      t.string :source_type, null: false
      t.string :name, null: false
      t.jsonb :config, default: {}
      t.string :status, default: 'active'
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :knowledge_sources, [:account_id, :source_type]
  end
end
