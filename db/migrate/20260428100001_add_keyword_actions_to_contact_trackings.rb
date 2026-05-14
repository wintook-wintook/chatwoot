# frozen_string_literal: true

# proyecto@contact_tracking
class AddKeywordActionsToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :keyword_actions, :jsonb, default: [], null: false
  end
end
