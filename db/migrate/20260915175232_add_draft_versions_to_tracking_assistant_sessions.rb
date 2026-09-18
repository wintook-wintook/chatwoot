# proyecto@asistente_agentes_ia — fase D de PROMPT STUDIO
# Las versiones del Entrenamiento dentro de una conversación con el Asistente: una por
# entrega del asistente y una por cada tanda de edición a mano. Van en la sesión y no
# en una tabla aparte porque viven y mueren con ella, y tienen tope (ver
# TrackingAssistantSession::MAX_VERSIONS).
class AddDraftVersionsToTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_assistant_sessions, :draft_versions, :jsonb, default: [], null: false
  end
end
