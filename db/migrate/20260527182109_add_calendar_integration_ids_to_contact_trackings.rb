# proyecto@bot_seguimiento_calendar
class AddCalendarIntegrationIdsToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :calendar_integration_ids, :jsonb, default: [], null: false
  end
end
