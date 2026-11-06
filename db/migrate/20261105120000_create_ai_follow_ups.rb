# Seguimiento IA — el agente nuevo con herramientas, que se activa con «Delegar a
# agente» desde el caso o pidiéndoselo a Dali. Tabla propia: no toca contact_trackings
# ni tracking_templates (el agente de seguimiento de siempre sigue igual).
class CreateAiFollowUps < ActiveRecord::Migration[7.0]
  def change # rubocop:disable Metrics/MethodLength
    create_table :ai_follow_ups do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :case_ticket, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.text :objective, null: false
      t.text :instructions
      t.string :status, null: false, default: 'active'
      t.datetime :next_run_at
      t.integer :max_attempts, null: false, default: 3
      t.integer :attempts, null: false, default: 0
      t.integer :interval_value, null: false, default: 1
      t.string :interval_unit, null: false, default: 'days'
      t.string :on_finish, null: false, default: 'notify'
      t.string :time_zone
      t.text :outcome
      t.text :last_error
      t.jsonb :log, null: false, default: []
      t.datetime :finished_at
      t.timestamps
    end
    add_index :ai_follow_ups, %i[status next_run_at]
    add_index :ai_follow_ups, :conversation_id, unique: true, where: "status IN ('active', 'paused')",
                                                name: 'index_ai_follow_ups_live_per_conversation'
  end
end
