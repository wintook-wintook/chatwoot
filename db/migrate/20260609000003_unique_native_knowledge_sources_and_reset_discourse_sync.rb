# @knowledge_sources
# 1) Resetea fuentes Discourse que quedaran atascadas en 'syncing' (sus jobs de sync
#    ya no existen, nunca volverían a 'idle' → polling infinito en el front).
# 2) Garantiza una sola fuente nativa por cuenta (canned_response / article):
#    de-duplica las que existan y añade un índice ÚNICO PARCIAL. Discourse queda fuera
#    a propósito (una cuenta puede tener varios foros).
class UniqueNativeKnowledgeSourcesAndResetDiscourseSync < ActiveRecord::Migration[6.1]
  NATIVE = %w[canned_response article].freeze

  def up
    # (#2) Resetear sync discourse atascado
    execute(<<~SQL.squish)
      UPDATE knowledge_sources
         SET sync_status = 'idle', sync_jobs_pending = 0
       WHERE source_type = 'discourse' AND sync_status = 'syncing'
    SQL

    # (#1a) Re-apuntar los knowledge_items de fuentes nativas duplicadas a la superviviente
    # (la de menor id por cuenta+tipo) antes de borrarlas, para no violar la FK.
    execute(<<~SQL.squish)
      WITH ranked AS (
        SELECT id, MIN(id) OVER (PARTITION BY account_id, source_type) AS keep_id
          FROM knowledge_sources
         WHERE source_type IN ('canned_response', 'article')
      )
      UPDATE knowledge_items ki
         SET knowledge_source_id = r.keep_id
        FROM ranked r
       WHERE ki.knowledge_source_id = r.id AND r.id <> r.keep_id
    SQL

    # (#1b) Borrar las fuentes nativas duplicadas (conservando la de menor id)
    execute(<<~SQL.squish)
      DELETE FROM knowledge_sources ks
       USING (
        SELECT id, MIN(id) OVER (PARTITION BY account_id, source_type) AS keep_id
          FROM knowledge_sources
         WHERE source_type IN ('canned_response', 'article')
       ) d
       WHERE ks.id = d.id AND d.id <> d.keep_id
    SQL

    # (#1c) Índice único parcial: una sola fuente por (cuenta, tipo) para los nativos.
    add_index :knowledge_sources, %i[account_id source_type], unique: true,
              where: "source_type IN ('canned_response', 'article')",
              name: 'idx_unique_native_knowledge_sources'
  end

  def down
    remove_index :knowledge_sources, name: 'idx_unique_native_knowledge_sources', if_exists: true
  end
end
