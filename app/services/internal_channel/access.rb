# frozen_string_literal: true

# feat/chat_interno (plan v2, R2) — QUIÉN VE QUÉ EN «INTERNO» Y QUÉ TIENE SIN LEER
# ============================================================================
# Una conversación interna solo la ven sus participantes (un directo, sus dos agentes; la
# de un equipo, sus miembros). Con el chat apagado en la cuenta no se ve ninguna.
# Los no leídos van por agente (conversation_participants.last_read_at): Chatwoot solo
# cuenta mensajes de clientes y su «visto» lo comparten todos los agentes.
# ============================================================================
module InternalChannel::Access
  module_function

  def internal_inbox_ids(account)
    account.inboxes.where(channel_type: 'Channel::Internal').pluck(:id)
  end

  # Una consulta de conversaciones (o de mensajes, con on: :conversation_id), sin las internas
  # donde el agente no participa.
  def scope(relation, user, account, column: :id)
    ids = internal_inbox_ids(account)
    return relation if ids.empty?

    hidden = Conversation.where(inbox_id: ids)
    hidden = hidden.where.not(id: participant_ids(user)) if account.internal_chat_enabled?
    relation.where.not(column => hidden.select(:id))
  end

  def can_see?(conversation, user)
    return true unless conversation.internal?
    return false unless conversation.account.internal_chat_enabled?

    conversation.conversation_participants.exists?(user_id: user.id)
  end

  def unread_count(conversation, user)
    participant = conversation.conversation_participants.find_by(user_id: user.id)
    return 0 if participant.nil?

    messages = from_others(conversation, user)
    messages = messages.where('messages.created_at > ?', participant.last_read_at) if participant.last_read_at
    messages.count
  end

  def mark_read!(conversation, user, at = Time.current)
    conversation.conversation_participants.where(user_id: user.id).update_all(last_read_at: at) # rubocop:disable Rails/SkipsModelValidations
  end

  # «Marcar como no leído»: el último mensaje de otro agente vuelve a contar.
  def mark_unread!(conversation, user)
    last = from_others(conversation, user).last
    mark_read!(conversation, user, last.created_at - 0.001.seconds) if last # justo antes del último
  end

  # Lo que escribieron los demás agentes (todo en «Interno» es saliente).
  def from_others(conversation, user)
    conversation.messages.where(message_type: :outgoing)
                .where.not("messages.sender_type = 'User' AND messages.sender_id = ?", user.id)
  end

  def participant_ids(user)
    ConversationParticipant.where(user_id: user.id).select(:conversation_id)
  end
end
