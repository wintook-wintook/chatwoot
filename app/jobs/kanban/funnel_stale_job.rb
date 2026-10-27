# frozen_string_literal: true

# Embudo de contactos E2 — vencimientos: una tarjeta abierta cuyo cliente no escribe
# en «Descartar tras N días» pasa sola a la columna de descarte con su motivo. (El
# «Frío» no mueve nada: lo calcula el tablero al pintar la tarjeta.)
# Con `resolve_on_stale` también se resuelve la conversación, en silencio: sin
# encuesta, sin mensaje de actividad y sin disparar automatizaciones de «resuelta»
# (al prospecto que dejó de contestar no le llega nada). Si vuelve a escribir, la
# conversación se reabre como siempre y la tarjeta regresa a la entrada.
class Kanban::FunnelStaleJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanTypeProcess.where(auto_move: true).where.not(discard_after_days: nil).find_each { |board| sweep(board) }
  end

  private

  def sweep(board)
    target = board.kanban_processes.stage_discarded.by_position.first
    return if target.nil?

    limit = board.discard_after_days.days.ago
    stale(board, limit).find_each do |conversation|
      mover = Kanban::FunnelMover.new(conversation)
      key = board.resolve_on_stale? ? 'reasons.stale_resolved' : 'reasons.stale'
      moved = mover.move!(board, target, source: 'rule', reason: mover.translate(key, days: board.discard_after_days))
      resolve_quietly(conversation) if moved && board.resolve_on_stale?
    rescue StandardError => e
      Rails.logger.error("[KanbanFunnel] vencimiento de la conversación #{conversation.id}: #{e.message}")
    end
  end

  # update_columns a propósito: sin callbacks no hay mensaje de actividad (que es lo
  # que dispara la encuesta), ni evento CONVERSATION_RESOLVED, ni webhooks.
  def resolve_quietly(conversation)
    return if conversation.resolved?

    conversation.update_columns(status: Conversation.statuses[:resolved], updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def stale(board, limit)
    open_columns = board.kanban_processes.stage_open.select(:id)
    last_customer = Message.unscoped.where(message_type: :incoming).where('messages.conversation_id = conversations.id')
                           .select('MAX(messages.created_at)')
    board.conversations.where(kanban_process_id: open_columns)
         .where("COALESCE((#{last_customer.to_sql}), conversations.created_at) < ?", limit)
  end
end
