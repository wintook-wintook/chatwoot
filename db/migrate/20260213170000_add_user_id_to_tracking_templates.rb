# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Migración: Agregar user_id a tracking_templates (agente creador)
# ================================================================================

class AddUserIdToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_reference :tracking_templates, :user, null: true, foreign_key: true, index: true
  end
end
