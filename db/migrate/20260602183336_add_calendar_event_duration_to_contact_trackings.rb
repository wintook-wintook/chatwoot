class AddCalendarEventDurationToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :calendar_event_duration, :integer, default: 30
  end
end
