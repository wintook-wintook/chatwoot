# @knowledge_sources
# Agrega chunk_index para soporte de chunking en knowledge_items.
# Un topic largo se divide en N chunks; cada uno es un knowledge_item independiente.
# El índice único pasa de (account, source_type, source_id)
#                      a (account, source_type, source_id, chunk_index).
class AddChunkIndexToKnowledgeItems < ActiveRecord::Migration[7.0]
  def change
    add_column :knowledge_items, :chunk_index, :integer, null: false, default: 0

    remove_index :knowledge_items, name: 'idx_knowledge_items_source'
    add_index :knowledge_items,
              %i[account_id source_type source_id chunk_index],
              unique: true,
              name: 'idx_knowledge_items_source'
  end
end
