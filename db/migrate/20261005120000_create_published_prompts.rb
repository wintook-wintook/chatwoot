# proyecto@publicar_prompts (F1) — la foto publicada de un Agente IA, que otras cuentas
# bajan como copia. Plan: docs/publicar_prompts_plan.md
class CreatePublishedPrompts < ActiveRecord::Migration[7.0]
  def change
    create_published_prompts
    add_reference :tracking_templates, :published_prompt, foreign_key: { on_delete: :nullify }
  end

  private

  def create_published_prompts
    create_table :published_prompts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      # El agente de origen; si el autor lo borra, la publicación sigue viva sin él.
      t.references :tracking_template, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.string :title, :objective, null: false
      t.text :description
      t.string :category
      t.text :ai_context
      t.text :prompt, null: false
      t.jsonb :keyword_actions, null: false, default: []
      t.jsonb :settings, null: false, default: {}
      t.jsonb :requirements, null: false, default: []
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: 'published'
      t.integer :downloads_count, null: false, default: 0
      t.datetime :published_at
      t.timestamps
      t.index [:status, :category]
    end
  end
end
