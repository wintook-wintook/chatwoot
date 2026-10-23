# frozen_string_literal: true

# Embudo de contactos — lo que pasa en la conversación mueve su tarjeta
# (ver Kanban::FunnelMover). Solo hace algo en tableros con «Movimiento automático».
class KanbanFunnelListener < BaseListener
  include Singleton

  REPLY_SENDERS = %w[User AgentBot Captain::Assistant].freeze

  def conversation_created(event)
    conversation, _account = extract_conversation_and_account(event)
    Kanban::FunnelMover.new(conversation).enter!
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnelListener] #{e.class}: #{e.message}")
  end

  def message_created(event)
    message, _account = extract_message_and_account(event)
    return customer_wrote(message) if customer_message?(message)
    return unless first_reply?(message)

    Kanban::FunnelMover.new(message.conversation).trigger!(:first_reply)
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnelListener] #{e.class}: #{e.message}")
  end

  def conversation_updated(event)
    conversation, _account = extract_conversation_and_account(event)
    added = labels_added(event.data[:changed_attributes])
    return if added.empty?

    Kanban::FunnelMover.new(conversation).trigger!(:label_added, labels: added)
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnelListener] #{e.class}: #{e.message}")
  end

  # E2 — conversación resuelta sin caso: «Se resuelve la conversación sin caso».
  def conversation_resolved(event)
    conversation, _account = extract_conversation_and_account(event)
    return if conversation.case_tickets.exists?

    Kanban::FunnelMover.new(conversation).trigger!(:conversation_resolved)
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnelListener] #{e.class}: #{e.message}")
  end

  private

  def customer_message?(message)
    message.present? && message.incoming? && message.conversation&.kanban_type_process_id.present?
  end

  # E2 — el cliente escribió: una tarjeta descartada regresa a la entrada y, si el
  # embudo lo pide, la IA analiza cuando termine de escribir.
  def customer_wrote(message)
    conversation = message.conversation
    Kanban::FunnelMover.new(conversation).reopen!
    Kanban::FunnelAiJob.schedule(message) if conversation.kanban_type_process&.ai_move?
  end

  # Primera respuesta pública de una persona o de la IA (no campañas ni avisos automáticos).
  def first_reply?(message)
    return false unless replied_by_us?(message)
    return false unless message.conversation&.kanban_type_process&.auto_move?

    message.conversation.messages.where(message_type: :outgoing, private: false, sender_type: REPLY_SENDERS)
           .where.not(id: message.id).where("(additional_attributes->'campaign_id') is null").none?
  end

  def replied_by_us?(message)
    message.present? && message.outgoing? && !message.private? && REPLY_SENDERS.include?(message.sender_type) &&
      message.additional_attributes.to_h['campaign_id'].blank?
  end

  def labels_added(changed)
    before, after = (changed || {}).with_indifferent_access[:label_list]
    Array(after).map(&:to_s) - Array(before).map(&:to_s)
  end
end
