# frozen_string_literal: true

# feat/plantillas_whatsapp_mejoras — quién creó la plantilla desde la pantalla de plantillas
# (la lista muestra «Creada por»). Las que llegan sincronizadas desde Meta quedan en nil.
class AddCreatedByToWhatsappTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :whatsapp_templates, :created_by_id, :bigint
    add_index :whatsapp_templates, :created_by_id
  end
end
