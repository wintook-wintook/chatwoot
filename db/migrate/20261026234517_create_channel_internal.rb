# feat/chat_interno (plan v2, R1) — «Interno» como canal real de Chatwoot.
#   channel_internal                      una por cuenta: el canal de la bandeja «Interno»
#   conversation_participants.last_read_at hasta dónde leyó cada agente una conversación
#                                          interna (Chatwoot solo tiene un «visto» compartido)
class CreateChannelInternal < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_internal do |t|
      t.integer :account_id, null: false
      t.timestamps
    end
    add_index :channel_internal, :account_id, unique: true

    add_column :conversation_participants, :last_read_at, :datetime
  end
end
