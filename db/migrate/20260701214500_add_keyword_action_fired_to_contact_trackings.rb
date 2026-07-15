# proyecto@contact_tracking — KPIs de reglas
# ================================================================================
# Migración: Agregar keyword_action_fired a contact_trackings
# ================================================================================
# Atribución estructurada de la regla (palabra clave de acción) que disparó y
# cerró/pausó el seguimiento. Nullable: la mayoría de seguimientos nunca dispara
# una regla. Permite calcular efectividad de reglas en el dashboard.
#   Forma: { "keyword": "#cancelar", "action": "cancel",
#            "direction": "incoming", "fired_at": "2026-07-01T21:45:00Z" }
# ================================================================================

class AddKeywordActionFiredToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :keyword_action_fired, :jsonb
  end
end
