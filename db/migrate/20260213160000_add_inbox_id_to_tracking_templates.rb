# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Migración: Agregar inbox_id a tracking_templates (canal asociado)
# ================================================================================

class AddInboxIdToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_reference :tracking_templates, :inbox, null: true, foreign_key: true, index: true
  end
end
