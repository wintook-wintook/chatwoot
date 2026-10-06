# frozen_string_literal: true

# @tickets_cases — User Portal R2
# Si el portal enruta a un inbox de WhatsApp, el acuse del folio debe enviarse con
# una plantilla aprobada (regla de 24h de Meta). Aquí se guarda qué plantilla usar.
class AddAcuseTemplateToCasePortals < ActiveRecord::Migration[7.0]
  def change
    add_column :case_portals, :acuse_template_name, :string
    add_column :case_portals, :acuse_template_language, :string, null: false, default: 'es'
  end
end
