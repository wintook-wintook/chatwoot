# frozen_string_literal: true

# proyecto@asistente_agentes_ia — nombre puesto a mano a una conversación del Asistente
# (25/09/2026: varias se llamaban igual y no se distinguían en «En construcción»).
class AddNameToTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_assistant_sessions, :name, :string
  end
end
