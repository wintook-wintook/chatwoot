# frozen_string_literal: true

# feat/chat_interno (F1) — SALAS DEL CHAT INTERNO
# ============================================================================
# GET    /api/v1/accounts/:account_id/internal_chat/rooms            las del agente, con no leídos
# GET    /api/v1/accounts/:account_id/internal_chat/rooms/:id        una sala
# POST   /api/v1/accounts/:account_id/internal_chat/rooms            { kind: 'direct', user_id } o
#                                                                    { kind: 'group', name, user_ids: [] }
# PATCH  /api/v1/accounts/:account_id/internal_chat/rooms/:id        { name }  (grupo: dueño o administrador)
# POST   /api/v1/accounts/:account_id/internal_chat/rooms/:id/read   «leído hasta ahora»
# ============================================================================
class Api::V1::Accounts::InternalChat::RoomsController < Api::V1::Accounts::InternalChat::BaseController
  def index
    render json: { payload: ::InternalChat::RoomList.new(account: Current.account, user: Current.user).call }
  end

  def show
    render_room
  end

  def create
    created = if params[:kind] == 'group'
                rooms_service.group!(params[:name], params[:user_ids])
              else
                rooms_service.direct!(params[:user_id])
              end
    render_room(created, status: :created)
  rescue ::InternalChat::Rooms::Error, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    return head :forbidden unless room.manageable_by?(Current.user, Current.account_user)

    room.update!(name: params[:name].to_s.strip)
    ::InternalChat::Broadcaster.room_updated(room)
    render_room
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def read
    member = InternalChatMember.find_or_initialize_by(room: room, user: Current.user)
    member.update!(last_read_at: Time.current)
    head :ok
  end

  private

  def rooms_service
    ::InternalChat::Rooms.new(account: Current.account, user: Current.user)
  end
end
