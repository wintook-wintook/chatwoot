# frozen_string_literal: true

# feat/chat_interno (F1) — PUERTA COMÚN DEL CHAT INTERNO
# Con el chat apagado en la cuenta no responde nada (404). Una sala solo la abre quien
# está en ella (la general, cualquier agente de la cuenta): ni el administrador lee los
# directos de otros (decisión D2).
class Api::V1::Accounts::InternalChat::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_internal_chat_enabled

  private

  def ensure_internal_chat_enabled
    head :not_found unless Current.account.internal_chat_enabled?
  end

  def room
    @room ||= begin
      found = Current.account.internal_chat_rooms.find(params[:room_id] || params[:id])
      raise ActiveRecord::RecordNotFound unless found.accessible_by?(Current.user)

      found
    end
  end

  def render_room(target = room, status: :ok)
    unread = ::InternalChat::RoomList.unread_count_for(target, Current.user)
    render json: ::InternalChat::Presenter.room(target, unread_count: unread), status: status
  end
end
