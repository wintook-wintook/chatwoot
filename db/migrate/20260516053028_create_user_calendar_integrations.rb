class CreateUserCalendarIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :user_calendar_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :google_email
      t.jsonb :tokens, default: {}
      t.jsonb :enabled_calendar_ids, default: []
      t.boolean :alert_enabled, default: true
      t.integer :alert_minutes_before, default: 15
      t.timestamps
    end

    add_index :user_calendar_integrations, [:user_id, :account_id], unique: true
  end
end
