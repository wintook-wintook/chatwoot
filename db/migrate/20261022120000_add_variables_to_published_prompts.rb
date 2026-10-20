# frozen_string_literal: true

# proyecto@adaptar_prompts_publicados (F4) — los datos del negocio que el autor marcó como
# variables al publicar: [{ "text": "Grúas del Norte", "label": "Nombre del negocio" }].
# Se guardan para prellenar la ventana al republicar.
class AddVariablesToPublishedPrompts < ActiveRecord::Migration[7.0]
  def change
    add_column :published_prompts, :variables, :jsonb, null: false, default: []
  end
end
