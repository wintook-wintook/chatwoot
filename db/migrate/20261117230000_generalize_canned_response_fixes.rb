# proyecto@arreglar_predefinidas F2 — un arreglo con IA para cada sección de la auditoría:
#   kind            oversize (pasa el tope) | writing (redacción) | merge (unir duplicadas o
#                   que se solapan) | separate (separar temas) | resolve (contradicción)
#   finding_id      el hallazgo que se está arreglando
#   source_ids      las predefinidas de origen, en orden (A, B, y las que se corrigen de paso)
#   source_digests  { id => huella del texto } al proponer: si cambian, la propuesta no aplica
#   input           lo que eligió la persona (qué dato es el correcto, cuáles corregir de paso)
#   snapshot        cómo estaban las de origen antes de aplicar, para «Deshacer»
#   batch           «Corregir todas» de redacción: las propuestas del mismo lote
#   undone_at       cuándo se deshizo
class GeneralizeCannedResponseFixes < ActiveRecord::Migration[7.0]
  def up
    change_table :canned_response_fixes, bulk: true do |t|
      t.string :kind, null: false, default: 'oversize'
      t.references :finding, foreign_key: { to_table: :canned_response_findings, on_delete: :nullify }
      t.jsonb :source_ids, null: false, default: []
      t.jsonb :source_digests, null: false, default: {}
      t.jsonb :input, null: false, default: {}
      t.jsonb :snapshot, null: false, default: []
      t.string :batch
      t.datetime :undone_at
    end
    add_index :canned_response_fixes, [:account_id, :status]
    add_index :canned_response_fixes, :batch
    execute <<~SQL.squish
      UPDATE canned_response_fixes
      SET source_ids = jsonb_build_array(canned_response_id),
          source_digests = jsonb_build_object(canned_response_id::text, source_digest)
      WHERE canned_response_id IS NOT NULL
    SQL
    change_column_null :canned_response_fixes, :source_digest, true
  end

  def down
    change_column_null :canned_response_fixes, :source_digest, false
    remove_index :canned_response_fixes, :batch
    remove_index :canned_response_fixes, [:account_id, :status]
    change_table :canned_response_fixes, bulk: true do |t|
      t.remove_references :finding, foreign_key: { to_table: :canned_response_findings }
      t.remove :kind, :source_ids, :source_digests, :input, :snapshot, :batch, :undone_at
    end
  end
end
