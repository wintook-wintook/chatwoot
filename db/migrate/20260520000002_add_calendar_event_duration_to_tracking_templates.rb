class AddCalendarEventDurationToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :calendar_event_duration, :integer, default: 30
  end
end
