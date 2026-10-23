# frozen_string_literal: true

# Embudo de contactos E2 — la IA analiza cuando el cliente deja de escribir: el job
# se agenda DEBOUNCE después de cada mensaje del cliente y solo corre el del último
# (si llegó otro mensaje después, ese otro job hará el análisis).
class Kanban::FunnelAiJob < ApplicationJob
  DEBOUNCE = 2.minutes
  queue_as :low

  def self.schedule(message)
    set(wait: DEBOUNCE).perform_later(message.conversation_id, message.id)
  end

  def perform(conversation_id, message_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.nil? || !conversation.kanban_type_process&.ai_move?
    return if conversation.messages.incoming.exists?(['id > ?', message_id])

    Kanban::FunnelAi.new(conversation).call
  end
end
