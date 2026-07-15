# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar
# Mapa { integration_id => google_calendar_id } que indica EN QUÉ calendario de Google
# se crea la cita por cada agenda vinculada. Sin valor → 'primary' (comportamiento previo).
class AddBookingCalendarIdsToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :booking_calendar_ids, :jsonb, null: false, default: {}
  end
end
