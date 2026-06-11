class AddTrackingTemplateIdToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :tracking_template_id, :integer
  end
end
