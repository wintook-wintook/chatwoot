# @knowledge_sources
# Tabla de ítems vectorizados de la base de conocimiento.
# embedding: vector(1536) de OpenAI text-embedding-3-small
# source_type + source_id: referencia al registro original
class CreateKnowledgeItems < ActiveRecord::Migration[6.1]
  def change
    create_table :knowledge_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :knowledge_source, null: false, foreign_key: true
      t.string :source_type, null: false
      t.integer :source_id, null: false
      t.string :title
      t.text :content, null: false
      t.vector :embedding, limit: 1536
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :knowledge_items, [:account_id, :source_type, :source_id], unique: true,
              name: 'idx_knowledge_items_source'
    add_index :knowledge_items, :embedding, using: :ivfflat,
              opclass: :vector_cosine_ops, name: 'idx_knowledge_items_embedding'
  end
end
