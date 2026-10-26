# frozen_string_literal: true

# feat/chat_interno — LAS SALAS DE UN AGENTE, CON SUS NO LEÍDOS
# ============================================================================
# La general siempre existe (se crea la primera vez) y el agente siempre la ve. Al
# entrar por primera vez su «leído hasta» arranca en este momento: no le aparece como
# sin leer todo el historial de la cuenta.
# No leídos y último mensaje se calculan en una consulta cada uno (sin N+1).
# ============================================================================
class InternalChat::RoomList
  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def call
    ensure_general_membership
    rooms = InternalChatRoom.where(account: @account).visible_to(@user)
                            .includes(:members, users: { avatar_attachment: :blob }).to_a
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
    members = room.general? ? account_users : room.users.to_a
    InternalChat::Presenter.room(room, members: members, unread_count: unread[room.id].to_i, last_message: last[room.id])
  end

  def account_users
    @account_users ||= @account.users.includes(avatar_attachment: :blob).to_a
  end

  def ensure_general_membership
    general = InternalChatRoom.general_for(@account)
    InternalChatMember.find_or_create_by!(room: general, user: @user) { |member| member.last_read_at = Time.current }
  rescue ActiveRecord::RecordNotUnique
    nil
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
