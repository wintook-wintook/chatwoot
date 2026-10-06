# proyecto@publicar_prompts (F6) — los archivos del agente ({{nombre}}) que el autor
# eligió publicar junto con el prompt. Copias propias: no dependen del agente del autor.
# Plan: docs/publicar_prompts_plan.md
class CreatePublishedPromptFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :published_prompt_files do |t|
      t.references :published_prompt, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.timestamps
      t.index [:published_prompt_id, :name], unique: true
    end
  end
end
