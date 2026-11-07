# frozen_string_literal: true

# Asistente (Dali) — preguntas de uso que Dali no supo contestar: no encontró guía, la
# guía no lo cubría o el usuario marcó 👎. Solo las ve el equipo de Kontrolya (Super
# Admin) para escribir o corregir las guías de config/assistant/guides. La misma
# pregunta pendiente suma `occurrences` en vez de repetirse. Idempotente.
class CreateAssistantGuideGaps < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:assistant_guide_gaps)

    create_table :assistant_guide_gaps do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.text :question, null: false
      t.string :normalized, null: false
      t.text :answer
      t.string :page
      t.string :guide_key
      t.string :reason, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :occurrences, null: false, default: 1
      t.string :resolution_note
      t.datetime :last_asked_at, null: false
      t.timestamps
    end
    add_index :assistant_guide_gaps, %i[status last_asked_at]
    add_index :assistant_guide_gaps, %i[account_id normalized reason status], name: 'index_assistant_guide_gaps_dedupe'
  end

  def down
    drop_table :assistant_guide_gaps, if_exists: true
  end
end
