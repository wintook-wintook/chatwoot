# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar — zona horaria propia del Agente IA para agendar.
# Antes el bot usaba SIEMPRE la zona del inbox (default "UTC"), así que los slots 9-18,
# la hora mostrada y el evento caían en UTC salvo que se configurara el inbox.
# Ahora cada Agente IA puede fijar su zona; si queda en blanco se cae al inbox y luego
# a un default. Nullable a propósito (no imponer una zona a los agentes existentes).
class AddTimezoneToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :timezone, :string
  end
end
