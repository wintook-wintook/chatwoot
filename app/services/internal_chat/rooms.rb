# frozen_string_literal: true

# feat/chat_interno (F1) — ABRIR DIRECTOS, CREAR GRUPOS Y CAMBIAR MIEMBROS
# ============================================================================
# Solo pueden estar en una sala los agentes de la cuenta: cualquier id de fuera se ignora.
#   direct!(otro)               el directo entre los dos (si ya existe, el mismo)
#   group!(nombre, ids)         grupo nuevo; quien lo crea queda de dueño
#   add_members!/remove_member!  solo grupos (el permiso lo revisa el controlador)
# ============================================================================
class InternalChat::Rooms
  class Error < StandardError; end

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def direct!(other_user_id)
    other = account_user_ids.include?(other_user_id.to_i) ? other_user_id.to_i : nil
    raise Error, 'invalid_user' if other.nil? || other == @user.id

    key = InternalChatRoom.direct_key_for(@user.id, other)
    existing = @account.internal_chat_rooms.find_by(direct_key: key)
    return existing if existing

    create_room!(kind: 'direct', direct_key: key, member_ids: [@user.id, other])
  rescue ActiveRecord::RecordNotUnique
    @account.internal_chat_rooms.find_by!(direct_key: key)
  end

  def group!(name, user_ids)
    create_room!(kind: 'group', name: name.to_s.strip, member_ids: [@user.id, *valid_ids(user_ids)])
  end

  def add_members!(room, user_ids)
    ids = valid_ids(user_ids) - room.members.pluck(:user_id)
    ids.each { |id| room.members.create!(user_id: id, role: 'member', last_read_at: Time.current) }
    InternalChat::Broadcaster.room_updated(room.reload) if ids.any?
    room
  end

  def remove_member!(room, user_id)
    member = room.members.find_by(user_id: user_id)
    return room if member.nil?

    member.destroy!
    InternalChat::Broadcaster.room_removed(room, [member.user_id])
    InternalChat::Broadcaster.room_updated(room.reload)
    room
  end

  private

  def create_room!(kind:, member_ids:, name: nil, direct_key: nil)
    room = ActiveRecord::Base.transaction do
      created = @account.internal_chat_rooms.create!(kind: kind, name: name, direct_key: direct_key, created_by: @user)
      member_ids.uniq.each do |id|
        created.members.create!(user_id: id, role: id == @user.id && kind == 'group' ? 'owner' : 'member',
                                last_read_at: Time.current)
      end
      created
    end
    InternalChat::Broadcaster.room_updated(room)
    room
  end

  def valid_ids(user_ids)
    Array(user_ids).map(&:to_i) & account_user_ids
  end

  def account_user_ids
    @account_user_ids ||= @account.account_users.pluck(:user_id)
  end
end
