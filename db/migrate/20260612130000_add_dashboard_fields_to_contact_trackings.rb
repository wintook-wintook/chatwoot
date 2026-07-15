# frozen_string_literal: true

# proyecto@contact_tracking — Fase 0 del Dashboard de Seguimientos
# Columnas aditivas (nullable) para KPIs consultables por índice, en vez de
# parsear texto de ai_context / jsonb:
#   - appointment_at: fecha/hora de la cita agendada (hoy vive como [CITA AGENDADA] en ai_context)
#   - last_intent:    última intención clasificada (hoy en last_sentiment_analysis->>'sentiment')
#   - outcome:        resultado del seguimiento (appointment / interested / rejected / ...)
class AddDashboardFieldsToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :appointment_at, :datetime
    add_column :contact_trackings, :last_intent, :string
    add_column :contact_trackings, :outcome, :string

    add_index :contact_trackings, :appointment_at
    add_index :contact_trackings, :last_intent
  end
end
