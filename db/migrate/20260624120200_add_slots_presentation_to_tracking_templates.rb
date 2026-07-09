# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar
# Formato con el que el Agente IA presenta los horarios disponibles al cliente:
# 'detailed' (default, todo en cada línea) | 'by_agent' (agrupado por profesional) |
# 'simple' (sin zona ni profesional) | 'by_day' (agrupado por día).
class AddSlotsPresentationToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :slots_presentation, :string, default: 'detailed', null: false
  end
end
