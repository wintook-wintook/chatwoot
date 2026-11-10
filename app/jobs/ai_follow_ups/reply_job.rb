# frozen_string_literal: true

# Seguimiento IA — el cliente escribió en una conversación con un seguimiento activo.
# Espera unos segundos (Message#analyze_for_active_trackings lo encola con espera) y solo
# contesta el último mensaje: si el cliente mandó varios seguidos, se contesta una vez.
class AiFollowUps::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming?

    follow_up = AiFollowUp.active.find_by(conversation_id: message.conversation_id)
    return unless follow_up
    return if newer_incoming?(message) || answered?(message)

    AiFollowUps::Runner.new(follow_up, trigger: :reply).call
  end

  private

  def newer_incoming?(message)
    message.conversation.messages.incoming.exists?(['id > ?', message.id])
  end

  def answered?(message)
    message.conversation.messages.where(message_type: :outgoing, private: false).where('id > ?', message.id)
           .where("#{AiFollowUp.message_attr_sql('ai_follow_up_id')} IS NOT NULL").exists?
  end
end
