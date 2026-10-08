# proyecto@publicar_prompts (F7) — qué versión de la publicación bajó (o ya revisó) cada
# copia, para avisar cuando el autor publica una más nueva. Plan: docs/publicar_prompts_plan.md
class AddPublishedPromptVersionToTrackingTemplates < ActiveRecord::Migration[7.0]
  def up
    add_column :tracking_templates, :published_prompt_version, :integer
    # Las copias bajadas antes de esta columna se dan por al día: no hay forma de saber
    # qué versión bajaron, y avisar de una «versión nueva» que quizá ya tienen confunde.
    execute <<~SQL.squish
      UPDATE tracking_templates t SET published_prompt_version = p.version
      FROM published_prompts p WHERE t.published_prompt_id = p.id
    SQL
  end

  def down
    remove_column :tracking_templates, :published_prompt_version
  end
end
