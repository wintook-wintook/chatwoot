# @knowledge_sources — WordPress trae ids AJENOS, y eso rompe dos supuestos que
# valían mientras todas las fuentes usaban ids internos de Rails:
#
#   1. source_id era `integer` (tope 2.147.483.647). Un id de WooCommerce visto en
#      una tienda real es 18.734.006.862.930: 8.700 veces el tope. Se ensancha a
#      bigint, que es lo mismo que ya son account_id y knowledge_source_id.
#
#   2. El índice único era (account_id, source_type, source_id, chunk_index). Como
#      source_type sería 'wordpress' para TODOS los sitios de una cuenta, dos sitios
#      con una entrada #412 colisionaban y el segundo pisaba al primero. Se agrega
#      knowledge_source_id, que es lo que distingue un sitio de otro.
#
# Las fuentes que ya existen no cambian de comportamiento: usan source.id como
# source_id, así que agregar knowledge_source_id al índice no altera su unicidad.
class WidenKnowledgeItemsSourceId < ActiveRecord::Migration[7.0]
  def up
    change_column :knowledge_items, :source_id, :bigint

    remove_index :knowledge_items, name: 'idx_knowledge_items_source'
    add_index :knowledge_items,
              %i[account_id source_type knowledge_source_id source_id chunk_index],
              unique: true, name: 'idx_knowledge_items_source'
  end

  def down
    remove_index :knowledge_items, name: 'idx_knowledge_items_source'
    add_index :knowledge_items,
              %i[account_id source_type source_id chunk_index],
              unique: true, name: 'idx_knowledge_items_source'

    change_column :knowledge_items, :source_id, :integer
  end
end
