# frozen_string_literal: true

# El agente listo en una conversación: «Atendida por Sofi» con Pausar / Reanudar.
# GET   /ready_agent_sessions?conversation_id=   la plática viva o la última (o nada)
# PATCH /ready_agent_sessions/:id/pause | resume | cancel_follow_up (no más recordatorios: Motor2::FollowUp)
# Desde §11.14.5 los agentes de función (motor 2.0) atienden con un contact_tracking: su id viaja
# como «t<id>». Las sesiones de antes (ready_agent_sessions) se siguen viendo mientras existan.
class Api::V1::Accounts::ReadyAgentSessionsController < Api::V1::Accounts::BaseController
  TRACKING = /\At(\d+)\z/

  def index
    conversation = visible_conversations.find_by(display_id: params[:conversation_id])
    tracking = conversation && function_trackings.where(conversation_id: conversation.id).order(:id).last
    return render json: { session: tracking_json(tracking) } if tracking

    session = conversation && ReadyAgentSession.where(conversation_id: conversation.id).order(:id).last
    render json: { session: session && session_json(session) }
  end

  def pause
    change(:pause)
  end

  def resume
    change(:resume)
  end

  def cancel_follow_up
    tracking = function_trackings.find(params[:id].to_s[TRACKING, 1])
    return render_access_denied unless visible_conversations.exists?(id: tracking.conversation_id)

    Motor2::FollowUp.cancel!(tracking)
    render json: { session: tracking_json(tracking.reload) }
  end

  private

  def visible_conversations
    access_grant.conversations(Current.account.conversations)
  end

  def function_trackings
    ContactTracking.where(account_id: Current.account.id).joins(:tracking_template)
                   .where(tracking_templates: { agent_function: Motor2::Functions::CLASSES.keys })
  end

  def change(action)
    id = params[:id].to_s[TRACKING, 1]
    return change_tracking(function_trackings.find(id), action) if id

    session = Current.account.ready_agent_sessions.find(params[:id])
    return render_access_denied unless visible_conversations.exists?(id: session.conversation_id)

    action == :pause ? session.pause!(by: current_user) : session.resume!(by: current_user)
    render json: { session: session_json(session.reload) }
  end

  # Pausado = lo atiende una persona; al reanudar vuelve a contestar (sin intentos).
  def change_tracking(tracking, action)
    return render_access_denied unless visible_conversations.exists?(id: tracking.conversation_id)

    if action == :pause
      tracking.pause! if tracking.active?
    elsif tracking.paused?
      tracking.update!(status: 'active', paused_at: nil)
    end
    render json: { session: tracking_json(tracking.reload) }
  end

  def tracking_json(tracking)
    template = tracking.tracking_template
    result = Motor2::Functions::AgentJson.result_of(tracking.status, tracking.outcome)
    status = result == 'live' ? 'active' : result || tracking.status
    status = 'paused' if tracking.paused? && result != 'handed_off'
    state = tracking.motor2_state.to_h
    { id: "t#{tracking.id}", status: status, outcome: tracking.outcome, answers: state['answers'].to_h, updated_at: tracking.updated_at,
      agent: { id: template.id, name: template.name, kind: template.agent_function }, log: [],
      next_touch: Motor2::FollowUp.next_touch(tracking) }
  end

  def session_json(session)
    session.slice(:id, :status, :outcome, :answers, :updated_at)
           .merge(agent: session.ready_agent.slice(:id, :name, :kind), log: Array(session.log).last(10))
  end
end
