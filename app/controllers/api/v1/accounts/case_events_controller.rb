# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseEventsController
#
# GET /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/case_events
#
# Retorna el timeline completo del ticket ordenado por created_at ASC.
# Los eventos son inmutables — solo lectura.
# ================================================================================

class Api::V1::Accounts::CaseEventsController < Api::V1::Accounts::BaseController
  before_action :set_ticket

  # GET /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/case_events
  def index
    events = @ticket.case_events.order(created_at: :asc)
    render json: { case_events: events.map { |e| event_json(e) } }
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def event_json(event)
    {
      id:         event.id,
      event_type: event.event_type,
      origin:     event.origin,
      payload:    event.payload,
      created_at: event.created_at,
      actor:      actor_json(event.actor)
    }
  end

  def actor_json(user)
    return nil unless user

    { id: user.id, name: user.name, avatar_url: user.avatar_url }
  end
end
