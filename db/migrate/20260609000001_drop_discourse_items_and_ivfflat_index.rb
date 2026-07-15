# @knowledge_sources
# Las fuentes Discourse se consultan EN VIVO vía el plugin Discourse AI
# (@buscar_foro / @discourse), nunca usan knowledge_items locales.
# - Borra los knowledge_items de tipo 'discourse' (datos muertos de un diseño previo).
# - Elimina el índice IVFFlat: con el corpus reducido (canned_response + article, cientos
#   de filas), probes=1 destruía el recall. El KNN exacto (seq scan sobre vector_cosine)
#   es instantáneo a esta escala y 100% preciso.
class DropDiscourseItemsAndIvfflatIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    # 1) Borrar ítems discourse vectorizados localmente (ya no se usan)
    execute("DELETE FROM knowledge_items WHERE source_type = 'discourse'")

    # 2) Quitar el índice IVFFlat aproximado
    remove_index :knowledge_items, name: 'idx_knowledge_items_embedding', if_exists: true
  end

  def down
    add_index :knowledge_items, :embedding, using: :ivfflat,
              opclass: :vector_cosine_ops, name: 'idx_knowledge_items_embedding'
  end
end
