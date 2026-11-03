# frozen_string_literal: true

# Plan Actividad del caso — GET /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/activity
#   { tz: 'America/Mexico_City' }  → zona del usuario para agrupar los mensajes por día
# Todo lo que pasó en el caso en una sola lista (ver Cases::ActivityFeed).
class Api::V1::Accounts::CaseActivitiesController < Api::V1::Accounts::BaseController
  def show
    ticket = account_case_tickets.find(params[:case_ticket_id])
    render json: Cases::ActivityFeed.new(ticket: ticket, zone: ActiveSupport::TimeZone[params[:tz].to_s]).call
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Caso no encontrado' }, status: :not_found
  end
end
