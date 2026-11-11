# frozen_string_literal: true

# El agente listo en una conversación: «Atendida por Sofi» con Pausar / Reanudar.
# GET   /ready_agent_sessions?conversation_id=   la sesión viva o la última (o nada)
# PATCH /ready_agent_sessions/:id/pause | resume
class Api::V1::Accounts::ReadyAgentSessionsController < Api::V1::Accounts::BaseController
  def index
    conversation = visible_conversations.find_by(display_id: params[:conversation_id])
    session = conversation && ReadyAgentSession.where(conversation_id: conversation.id).order(:id).last
    render json: { session: session && session_json(session) }
  end

  def pause
    change { |session| session.pause!(by: current_user) }
  end

  def resume
    change { |session| session.resume!(by: current_user) }
  end

  private

  def visible_conversations
    access_grant.conversations(Current.account.conversations)
  end

  def change
    session = Current.account.ready_agent_sessions.find(params[:id])
    return render_access_denied unless visible_conversations.exists?(id: session.conversation_id)

    yield session
    render json: { session: session_json(session.reload) }
  end

  def session_json(session)
    session.slice(:id, :status, :outcome, :answers, :updated_at)
           .merge(agent: session.ready_agent.slice(:id, :name, :kind), log: Array(session.log).last(10))
  end
end
