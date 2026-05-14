# frozen_string_literal: true

# proyecto@contact_tracking
class AddKeywordActionsToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :keyword_actions, :jsonb, default: [], null: false
  end
end
