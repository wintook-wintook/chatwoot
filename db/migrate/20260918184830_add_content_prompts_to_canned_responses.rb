# frozen_string_literal: true

# proyecto@predefinidas_prompt — el prompt propio de cada respuesta predefinida
# (docs/predefinidas_prompt_plan.md).
#
# `unless column_exists?`: la columna ya existe en la base de donde salió el bot viejo
# —se coló al schema.rb desde allá, sin migración—, y un add_column pelado haría fallar
# el deploy ahí. En chatwoot_dev no existe, y por eso el formulario no guardaba.
class AddContentPromptsToCannedResponses < ActiveRecord::Migration[7.0]
  def up
    add_column :canned_responses, :content_prompts, :text unless column_exists?(:canned_responses, :content_prompts)
  end

  def down
    remove_column :canned_responses, :content_prompts if column_exists?(:canned_responses, :content_prompts)
  end
end
