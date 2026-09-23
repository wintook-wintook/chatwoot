# proyecto@asistente_agentes_ia — las instrucciones iniciales que se llenan conversando.
#
# Desde el 24/09/2026 el chat del Asistente, antes de que exista un Entrenamiento,
# conversa para llenar la plantilla de instrucciones iniciales (DraftingChat). Se
# guardan con la conversación para retomarla desde «En construcción» sin perderlas.
class AddInstructionsToTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_assistant_sessions, :instructions, :text
  end
end
