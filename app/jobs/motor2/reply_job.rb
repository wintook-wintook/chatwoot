# frozen_string_literal: true

# Motor 2.0 — el cliente escribió en una conversación con agente 2.0. Message lo encola con
# espera (Motor2::WAIT) y aquí se contesta solo el último mensaje: si mandó varios seguidos, o
# si ya se le contestó, no se repite. Si la conversación todavía no tiene agente y la bandeja tiene
# uno que la atiende (Motor2::InboxRouter), aquí empieza su seguimiento.
class Motor2::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming?

    return unless last_unanswered?(message)

    tracking = Motor2.tracking_for(message) || start(message)
    return hand_to_v1(message) unless tracking

    Motor2::Reply.new(tracking, message).call
  end

  private

  # Mientras esperaba, una automatización le dio un agente 1.0 a la conversación: contesta ese.
  def hand_to_v1(message)
    live = ContactTracking.where(conversation_id: message.conversation_id, status: Motor2::LIVE)
    ContactTrackingResponseAnalyzerJob.perform_later(message.id) if live.exists?
  end

  def start(message)
    template = Motor2::InboxRouter.agent_for(message)
    template && Motor2::InboxRouter.start(template, message)
  end

  def last_unanswered?(message)
    messages = message.conversation.messages
    !messages.incoming.exists?(['id > ?', message.id]) &&
      !messages.where(message_type: :outgoing, private: false).where('id > ?', message.id)
               .where("#{AiFollowUp.message_attr_sql('sentiment_auto_reply')} = 'true'").exists?
  end
end
