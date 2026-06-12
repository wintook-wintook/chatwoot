# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — Dashboard de Seguimientos (Fase 1)
# ================================================================================
# GET /api/v1/accounts/:account_id/contact_trackings/overview
#   Devuelve agregados a nivel cuenta para el dashboard:
#   summary (KPIs), by_status (donut) y lists.overdue (tabla de vencidos).
#   Filtros opcionales: inbox_id, template_id, date_from, date_to.
# ================================================================================
class Api::V1::Accounts::ContactTrackings::OverviewController < Api::V1::Accounts::BaseController
  ACTIVE_STATUSES = %w[pending scheduled active paused].freeze
  CLOSED_STATUSES = %w[completed cancelled failed].freeze

  def show
    scope = base_scope
    render json: {
      summary: summary(scope),
      by_status: by_status(scope),
      lists: { overdue: overdue_list(scope) }
    }
  end

  private

  def base_scope
    rel = ContactTracking.where(account_id: Current.account.id)
    rel = rel.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    rel = rel.where(tracking_template_id: params[:template_id]) if params[:template_id].present?
    rel = rel.where('created_at >= ?', params[:date_from]) if params[:date_from].present?
    rel = rel.where('created_at <= ?', params[:date_to]) if params[:date_to].present?
    rel
  end

  def summary(scope)
    completed = scope.where(status: 'completed').count
    closed    = scope.where(status: CLOSED_STATUSES).count
    {
      active:       scope.where(status: ACTIVE_STATUSES).count,
      overdue:      overdue(scope).count,
      due_24h:      scope.where(status: ACTIVE_STATUSES, scheduled_for: Time.current..24.hours.from_now).count,
      appointments: scope.where.not(appointment_at: nil).count,
      success_rate: closed.zero? ? 0 : (completed.to_f / closed).round(2),
      avg_attempts: scope.where(status: CLOSED_STATUSES).average(:attempt_count)&.round(1) || 0,
      total:        scope.count
    }
  end

  def by_status(scope)
    counts = scope.group(:status).count
    ContactTracking.statuses.keys.index_with { |s| counts[s] || 0 }
  end

  def overdue(scope)
    scope.where(status: %w[pending scheduled]).where('scheduled_for < ?', Time.current)
  end

  def overdue_list(scope)
    overdue(scope).order(scheduled_for: :asc).limit(20).map do |t|
      {
        id:            t.id,
        status:        t.status,
        objective:     t.objective,
        scheduled_for: t.scheduled_for,
        inbox_id:      t.inbox_id,
        contact_id:    t.contact_id,
        contact_name:  t.contact&.name,
        attempt_count: t.attempt_count,
        max_attempts:  t.max_attempts
      }
    end
  end
end
