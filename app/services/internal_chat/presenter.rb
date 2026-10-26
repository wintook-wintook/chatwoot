# frozen_string_literal: true

# feat/chat_interno — CÓMO SE VEN SALAS Y MENSAJES EN EL JSON
# Lo mismo para la API y para el tiempo real (Broadcaster). El nombre de un directo lo
# arma el dashboard con `members` (es «el otro» y depende de quién mira).
module InternalChat::Presenter
  module_function

  def user(user)
    return nil if user.nil?

    { id: user.id, name: user.name, available_name: user.available_name, avatar_url: user.avatar_url,
      availability_status: user.availability_status }
  end

  def message(message)
    {
      id: message.id,
      room_id: message.room_id,
      content: message.deleted? ? nil : message.content,
      deleted: message.deleted?,
      edited: message.edited_at.present?,
      created_at: message.created_at.to_i,
      sender: user(message.user)
    }
  end

  # extras: unread_count, last_message (los arma RoomList por lotes, sin N+1).
  def room(room, members: nil, unread_count: 0, last_message: nil)
    members ||= room_members(room)
    {
      id: room.id,
      kind: room.kind,
      name: room.display_name,
      team_id: room.team_id,
      created_by_id: room.created_by_id,
      last_message_at: timestamp(room.last_message_at),
      member_ids: members.map(&:id),
      members: members.map { |member| user(member) },
      unread_count: unread_count,
      last_message: last_message && message(last_message)
    }
  end

  def timestamp(time)
    time&.to_i
  end

  # La general es de toda la cuenta; la de un equipo, de sus miembros; un directo, de los dos.
  def room_members(room)
    room.member_users.to_a
  end
end
