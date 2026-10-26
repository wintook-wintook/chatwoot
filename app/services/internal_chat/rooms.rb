# frozen_string_literal: true

# feat/chat_interno (F1) — ABRIR UN DIRECTO
# Los grupos son los equipos de Chatwoot (InternalChatRoom.ensure_team_rooms!): no se crean
# aquí. Solo se abre un directo con otro agente de la cuenta; si ya existe, el mismo.
class InternalChat::Rooms
  class Error < StandardError; end

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def direct!(other_user_id)
    other = @account.account_users.exists?(user_id: other_user_id.to_i) ? other_user_id.to_i : nil
    raise Error, 'invalid_user' if other.nil? || other == @user.id

    key = InternalChatRoom.direct_key_for(@user.id, other)
    @account.internal_chat_rooms.find_by(direct_key: key) || create_direct!(key, other)
  rescue ActiveRecord::RecordNotUnique
    @account.internal_chat_rooms.find_by!(direct_key: key)
  end

  private

  def create_direct!(key, other)
    room = ActiveRecord::Base.transaction do
      created = @account.internal_chat_rooms.create!(kind: 'direct', direct_key: key, created_by: @user)
      [@user.id, other].each { |id| created.members.create!(user_id: id, last_read_at: Time.current) }
      created
    end
    InternalChat::Broadcaster.room_updated(room)
    room
  end
end
