# frozen_string_literal: true

# feat/chat_interno (F1) — MENSAJES DE UNA SALA
# GET  …/internal_chat/rooms/:room_id/messages?before=<id>   los últimos 50 (más viejos con before)
# POST …/internal_chat/rooms/:room_id/messages              { content }  → les llega a los miembros (F2)
class Api::V1::Accounts::InternalChat::MessagesController < Api::V1::Accounts::InternalChat::BaseController
  PAGE_SIZE = 50

  def index
    scope = room.messages.includes(user: { avatar_attachment: :blob }).order(id: :desc)
    scope = scope.where('id < ?', params[:before].to_i) if params[:before].present?
    page = scope.limit(PAGE_SIZE).to_a.reverse
    render json: { payload: page.map { |message| ::InternalChat::Presenter.message(message) },
                   meta: { has_more: page.size == PAGE_SIZE } }
  end

  def create
    message = room.messages.create!(user: Current.user, content: params[:content].to_s.strip)
    InternalChatMember.find_or_initialize_by(room: room, user: Current.user).update!(last_read_at: message.created_at)
    ::InternalChat::Broadcaster.message_created(message)
    render json: ::InternalChat::Presenter.message(message), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
