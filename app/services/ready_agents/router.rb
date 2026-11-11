# frozen_string_literal: true

# Agentes listos — ¿le toca a un agente listo contestar este mensaje del cliente?
# (Message#analyze_for_active_trackings lo pregunta después del Seguimiento IA, que manda
# primero.) Le toca si la bandeja tiene uno prendido y en esa conversación:
#   - ya atiende (sesión activa), o
#   - todavía no empieza: no hay sesión (ni pausada ni terminada) y ninguna persona le ha
#     escrito al cliente.
# Pausado o terminado no contesta: lo atiende una persona.
module ReadyAgents::Router
  module_function

  def agent_for(message)
    conversation = message.conversation
    return if conversation.nil? || conversation.internal?

    agent = ReadyAgent.for_inbox(conversation.inbox_id)
    return unless agent

    sessions = ReadyAgentSession.where(conversation_id: conversation.id)
    return agent if sessions.exists?(status: 'active')
    return if sessions.exists? || person_wrote?(conversation)

    agent
  end

  def takes?(message)
    agent_for(message).present?
  rescue StandardError => e
    Rails.logger.error("[ReadyAgents::Router] #{e.message}")
    false
  end

  def person_wrote?(conversation)
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end
end
