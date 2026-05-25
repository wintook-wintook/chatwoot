class AddCalendarIntegrationIdsToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :calendar_integration_ids, :jsonb, default: [], null: false
  end
end
