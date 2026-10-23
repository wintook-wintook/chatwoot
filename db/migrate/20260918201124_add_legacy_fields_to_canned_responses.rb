# frozen_string_literal: true

# proyecto@predefinidas_prompt — los campos que el formulario de respuestas predefinidas
# ya mostraba y mandaba, ahora guardados por la API de Chatwoot (docs/predefinidas_prompt_plan.md
# §3.5).
#
# Mismos tipos, defaults y nulabilidad que en chatwoot_staging_v2, donde ya existen con datos
# (1.870 respuestas: 563 con content_full, 697 con link, 309 en el menú). Por eso cada
# columna va con `unless column_exists?`: ahí la migración no hace nada y los datos quedan.
class AddLegacyFieldsToCannedResponses < ActiveRecord::Migration[7.0]
  COLUMNS = {
    content_full: [:boolean, { default: false, null: false }],
    url_content: [:boolean, { default: false, null: false }],
    url_short_code: [:text, {}],
    menu: [:boolean, { default: false, null: false }],
    opcion: [:bigint, { default: 0, null: false }]
  }.freeze

  def up
    COLUMNS.each do |name, (type, options)|
      add_column :canned_responses, name, type, **options unless column_exists?(:canned_responses, name)
    end
  end

  def down
    COLUMNS.each_key do |name|
      remove_column :canned_responses, name if column_exists?(:canned_responses, name)
    end
  end
end
