# frozen_string_literal: true

# feat/agentes_ia_unificado — de qué versión del agente partió la conversación del
# Asistente. Al publicar, si el agente cambió su Entrenamiento después de esa
# versión (otro admin publicó, se restauró una versión, se editó la ficha), se avisa
# en vez de pisarlo en silencio. NULL = conversación anterior a esto: no se revisa.
class AddBaseVersionToTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_assistant_sessions, :base_version, :integer
  end
end
