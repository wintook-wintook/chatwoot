# frozen_string_literal: true

# Motor 2.0 — el cliente escribió en una conversación con agente 2.0. Message lo encola con
# espera (Motor2::WAIT) y aquí se contesta solo el último mensaje: si mandó varios seguidos, o
# si ya se le contestó, no se repite.
class Motor2::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming?

    tracking = Motor2.tracking_for(message)
    return unless tracking && last_unanswered?(message)

    Motor2::Reply.new(tracking, message).call
  end

  private

  def last_unanswered?(message)
    messages = message.conversation.messages
    !messages.incoming.exists?(['id > ?', message.id]) &&
      !messages.where(message_type: :outgoing, private: false).where('id > ?', message.id)
               .where("#{AiFollowUp.message_attr_sql('sentiment_auto_reply')} = 'true'").exists?
  end
end
