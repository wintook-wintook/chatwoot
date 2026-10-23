# frozen_string_literal: true

# Embudo de contactos — los hechos que nacen fuera de la conversación (una cita, un
# caso) mueven la tarjeta en segundo plano: un fallo aquí no tumba lo que los creó.
class Kanban::FunnelTriggerJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, type, options = {})
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.nil?

    Kanban::FunnelMover.new(conversation).trigger!(type, **options.symbolize_keys)
  end
end
