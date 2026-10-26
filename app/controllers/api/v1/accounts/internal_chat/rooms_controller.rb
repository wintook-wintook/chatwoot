# frozen_string_literal: true

# feat/chat_interno (F1) — SALAS DEL CHAT INTERNO
# ============================================================================
# GET  /api/v1/accounts/:account_id/internal_chat/rooms            las del agente, con no leídos
# GET  /api/v1/accounts/:account_id/internal_chat/rooms/:id        una sala
# POST /api/v1/accounts/:account_id/internal_chat/rooms            { user_id }: abre el directo con él
# POST /api/v1/accounts/:account_id/internal_chat/rooms/:id/read   «leído hasta ahora»
# La general y las de los equipos se crean solas; sus miembros se cambian en Equipos.
# ============================================================================
class Api::V1::Accounts::InternalChat::RoomsController < Api::V1::Accounts::InternalChat::BaseController
  def index
    render json: { payload: ::InternalChat::RoomList.new(account: Current.account, user: Current.user).call }
  end

  def show
    render_room
  end

  def create
    created = ::InternalChat::Rooms.new(account: Current.account, user: Current.user).direct!(params[:user_id])
    render_room(created, status: :created)
  rescue ::InternalChat::Rooms::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def read
    member = InternalChatMember.find_or_initialize_by(room: room, user: Current.user)
    member.update!(last_read_at: Time.current)
    head :ok
  end
end
