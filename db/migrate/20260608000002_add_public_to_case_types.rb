# frozen_string_literal: true

# @tickets_cases — User Portal (P1)
# Solo los tipos marcados como públicos aparecen en el formulario del portal del
# cliente (equivalente a los Help Topics público/privado de osTicket).
class AddPublicToCaseTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :case_types, :public, :boolean, null: false, default: false
  end
end
