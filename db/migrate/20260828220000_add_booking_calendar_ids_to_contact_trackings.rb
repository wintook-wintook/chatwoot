# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar — @tickets_cases (recursos por ID_RECURSO)
# Mismo campo que ya existe en tracking_templates (mapa { integration_id =>
# [google_calendar_id, ...] }), pero a nivel de UN seguimiento puntual. Permite
# que un ContactTracking creado para UN recurso específico del catálogo (ej. una
# grúa con su propio calendario) agende SOLO en ese calendario, en vez del pool
# completo del Agente IA. Vacío (default) = sin override, se sigue leyendo del
# tracking_template como hasta ahora.
class AddBookingCalendarIdsToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :booking_calendar_ids, :jsonb, null: false, default: {}
  end
end
