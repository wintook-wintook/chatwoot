# frozen_string_literal: true

# feat/chat_interno (F1) — MIEMBROS DE UN GRUPO
# POST   …/internal_chat/rooms/:room_id/members           { user_ids: [] }  (dueño o administrador)
# DELETE …/internal_chat/rooms/:room_id/members/:id       sacar a alguien (dueño o administrador)
#                                                          o salirse uno mismo
class Api::V1::Accounts::InternalChat::MembersController < Api::V1::Accounts::InternalChat::BaseController
  def create
    return head :forbidden unless room.manageable_by?(Current.user, Current.account_user)

    rooms_service.add_members!(room, params[:user_ids])
    render_room
  end

  def destroy
    leaving = params[:id].to_i == Current.user.id
    return head :forbidden unless room.group? && (leaving || room.manageable_by?(Current.user, Current.account_user))

    rooms_service.remove_member!(room, params[:id])
    leaving ? head(:ok) : render_room
  end

  private

  def rooms_service
    ::InternalChat::Rooms.new(account: Current.account, user: Current.user)
  end
end
