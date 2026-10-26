# frozen_string_literal: true

# feat/chat_interno (F2) — TIEMPO REAL
# ============================================================================
# Reusa lo que ya existe: cada agente escucha su propio pubsub_token (RoomChannel) y
# ActionCableBroadcastJob manda a una lista de tokens. Solo les llega a los miembros de
# la sala (en la general, a todos los agentes de la cuenta); nunca a toda la cuenta.
#   internal_chat.message.created   un mensaje nuevo
#   internal_chat.room.updated      sala nueva (p. ej. alguien abrió un directo contigo)
# Plan: docs/chat_interno_plan.md §5
# ============================================================================
module InternalChat::Broadcaster
  module_function

  def message_created(message)
    room = message.room
    deliver(room.member_user_ids, 'internal_chat.message.created', room.account_id,
            message: InternalChat::Presenter.message(message))
  end

  def room_updated(room)
    deliver(room.member_user_ids, 'internal_chat.room.updated', room.account_id,
            room: InternalChat::Presenter.room(room))
  end

  def deliver(user_ids, event, account_id, data)
    tokens = User.where(id: user_ids).where.not(pubsub_token: nil).pluck(:pubsub_token)
    return if tokens.empty?

    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event, data.merge(account_id: account_id))
  end
end
