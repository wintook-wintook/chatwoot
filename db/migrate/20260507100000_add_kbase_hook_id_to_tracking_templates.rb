# frozen_string_literal: true

class AddKbaseHookIdToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :kbase_hook_id, :integer
    add_index  :tracking_templates, :kbase_hook_id
  end
end
