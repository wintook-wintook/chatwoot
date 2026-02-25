# Proyecto: DEV0001
class CreateScheduledMessages < ActiveRecord::Migration[6.1]
    def change
      create_table :scheduled_messages do |t|
        t.references :account, null: false, foreign_key: true
        t.references :conversation, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.text :content, null: false
        t.datetime :scheduled_at, null: false
        t.boolean :sent, default: false
        t.datetime :sent_at
        t.string :message_type, default: 'outgoing'
        t.json :additional_attributes
  
        t.timestamps
      end
      
      add_index :scheduled_messages, :scheduled_at
      add_index :scheduled_messages, :sent
    end
  end