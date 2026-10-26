# frozen_string_literal: true

# feat/chat_interno — LAS SALAS DE UN AGENTE, CON SUS NO LEÍDOS
# ============================================================================
# La general y las salas de los equipos se crean solas (la primera vez que alguien entra).
# El agente ve la general, las de SUS equipos y sus directos. La primera vez que entra a
# una, su «leído hasta» arranca en este momento: no le sale como pendiente el historial.
# No leídos y último mensaje se calculan en una consulta cada uno (sin N+1).
# ============================================================================
class InternalChat::RoomList
  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def call
    InternalChatRoom.general_for(@account)
    InternalChatRoom.ensure_team_rooms!(@account)
    rooms = InternalChatRoom.where(account: @account).visible_to(@user)
                            .includes(:team, users: { avatar_attachment: :blob }).to_a
    ensure_read_marks(rooms)
    unread = unread_counts(rooms.map(&:id))
    last = last_messages(rooms.map(&:id))
    rooms.sort_by { |room| [room.general? ? 0 : 1, -(room.last_message_at || room.created_at).to_i] }
         .map { |room| present(room, unread, last) }
  end

  def self.unread_count_for(room, user)
    new(account: room.account, user: user).send(:unread_counts, [room.id])[room.id].to_i
  end

  private

  def present(room, unread, last)
    members = room.general? ? account_users : room.member_users.includes(avatar_attachment: :blob).to_a
    InternalChat::Presenter.room(room, members: members, unread_count: unread[room.id].to_i, last_message: last[room.id])
  end

  def account_users
    @account_users ||= @account.users.includes(avatar_attachment: :blob).to_a
  end

  # General y equipos no llevan miembros fijos: la fila solo guarda hasta dónde leyó.
  def ensure_read_marks(rooms)
    known = InternalChatMember.where(user: @user, room_id: rooms.map(&:id)).pluck(:room_id)
    rooms.reject { |room| room.direct? || known.include?(room.id) }.each do |room|
      InternalChatMember.create!(room: room, user: @user, last_read_at: Time.current)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end

  # Mensajes de otros, no borrados, después de su «leído hasta».
  def unread_counts(room_ids)
    return {} if room_ids.empty?

    InternalChatMessage.joins('INNER JOIN internal_chat_members mem ON mem.room_id = internal_chat_messages.room_id')
                       .where(room_id: room_ids, deleted_at: nil)
                       .where(mem: { user_id: @user.id })
                       .where('internal_chat_messages.user_id IS NULL OR internal_chat_messages.user_id <> ?', @user.id)
                       .where('mem.last_read_at IS NULL OR internal_chat_messages.created_at > mem.last_read_at')
                       .group('internal_chat_messages.room_id').count
  end

  def last_messages(room_ids)
    return {} if room_ids.empty?

    InternalChatMessage.where(room_id: room_ids)
                       .select('DISTINCT ON (room_id) internal_chat_messages.*')
                       .order(:room_id, id: :desc)
                       .includes(user: { avatar_attachment: :blob })
                       .index_by(&:room_id)
  end
end
