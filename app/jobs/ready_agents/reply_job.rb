# frozen_string_literal: true

# Agentes listos — el cliente escribió en una bandeja con agente listo. Espera unos segundos
# (Message#analyze_for_active_trackings lo encola con espera) y contesta solo el último
# mensaje: si el cliente mandó varios seguidos, se contesta una vez. La primera vez abre la
# sesión; si quien escribe ya es cliente, lo pasa a una persona (ReadyAgents::ClientHandoff).
class ReadyAgents::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    agent = message&.incoming? && ReadyAgents::Router.agent_for(message)
    return unless agent && last_unanswered?(message)

    session = session_for(agent, message.conversation)
    ReadyAgents::Runner.new(agent, session: session).call if session&.active?
  end

  private

  def session_for(agent, conversation)
    ReadyAgentSession.live.find_by(conversation_id: conversation.id) || start(agent, conversation)
  end

  def start(agent, conversation)
    session = ReadyAgentSession.create!(account: conversation.account, ready_agent: agent, conversation: conversation,
                                        contact: conversation.contact)
    return session unless agent.only_prospects? && ReadyAgents::ClientCheck.client?(conversation.contact)

    ReadyAgents::ClientHandoff.new(session).call
    nil
  rescue ActiveRecord::RecordNotUnique
    ReadyAgentSession.live.find_by(conversation_id: conversation.id)
  end

  def last_unanswered?(message)
    !newer_incoming?(message) && !answered?(message)
  end

  def newer_incoming?(message)
    message.conversation.messages.incoming.exists?(['id > ?', message.id])
  end

  def answered?(message)
    message.conversation.messages.where(message_type: :outgoing, private: false).where('id > ?', message.id)
           .where("#{AiFollowUp.message_attr_sql('ready_agent_session_id')} IS NOT NULL").exists?
  end
end
