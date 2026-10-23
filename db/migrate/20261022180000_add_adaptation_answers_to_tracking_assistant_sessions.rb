# feat/reemplazo_directo_variables — un agente «En construcción» todavía no tiene
# TrackingTemplate: lo reemplazado en «Configurar» se recuerda en la conversación y pasa
# al agente al guardarlo (TrackingAssistantSession#mark_saved!).
class AddAdaptationAnswersToTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_assistant_sessions, :adaptation_answers, :jsonb, null: false, default: {}
  end
end
