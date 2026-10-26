# feat/chat_interno (F0) — chat interno entre los agentes de una cuenta.
# Módulo propio, sin relación con conversations/messages (plan §2 y §4).
#   internal_chat_rooms     una sala: «general» (toda la cuenta), un directo o un grupo
#   internal_chat_members   quién está en la sala y hasta dónde leyó
#   internal_chat_messages  lo que se escribe
class CreateInternalChatTables < ActiveRecord::Migration[7.0]
  def change
    create_rooms
    create_members
    create_messages
  end

  private

  def create_rooms
    create_table :internal_chat_rooms do |t|
      t.bigint :account_id, null: false
      t.string :kind, null: false, default: 'group'
      t.string :name
      t.bigint :created_by_id
      # Solo en directos: «idMenor:idMayor», para que entre dos agentes haya uno solo.
      t.string :direct_key
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :internal_chat_rooms, :account_id
    add_index :internal_chat_rooms, [:account_id, :direct_key], unique: true, where: 'direct_key IS NOT NULL'
    add_index :internal_chat_rooms, [:account_id, :kind], unique: true, where: "kind = 'general'",
                                                          name: 'index_internal_chat_rooms_one_general'
  end

  def create_members
    create_table :internal_chat_members do |t|
      t.bigint :room_id, null: false
      t.bigint :user_id, null: false
      t.string :role, null: false, default: 'member'
      t.datetime :last_read_at
      t.boolean :muted, null: false, default: false
      t.timestamps
    end
    add_index :internal_chat_members, [:room_id, :user_id], unique: true
    add_index :internal_chat_members, :user_id
  end

  def create_messages
    create_table :internal_chat_messages do |t|
      t.bigint :room_id, null: false
      t.bigint :user_id
      t.text :content
      t.datetime :edited_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :internal_chat_messages, [:room_id, :id]
  end
end
