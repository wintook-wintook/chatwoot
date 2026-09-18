# frozen_string_literal: true

# proyecto@predefinidas_prompt — la casilla "El mensaje es el prompt" (docs/predefinidas_prompt_plan.md
# §3.6): marca que el mensaje de la respuesta no es información para el cliente, sino
# instrucciones para el agente IA. Es aparte de `content_prompts`, que sigue siendo el
# prompt que acompaña a un mensaje.
#
# Columna nueva: no existe en chatwoot_staging_v2. Va con `unless column_exists?` como las
# demás de esta tabla, por si alguna base la trae de antes.
class AddContentIsPromptToCannedResponses < ActiveRecord::Migration[7.0]
  def up
    return if column_exists?(:canned_responses, :content_is_prompt)

    add_column :canned_responses, :content_is_prompt, :boolean, default: false, null: false
  end

  def down
    remove_column :canned_responses, :content_is_prompt if column_exists?(:canned_responses, :content_is_prompt)
  end
end
