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
      by_inbox: by_inbox(scope),
      by_template: by_template(scope),
      funnel: funnel(scope),
      rules: rules(scope),
      timeseries: timeseries(scope),
      lists: { overdue: overdue_list(scope), appointments: appointments_list(scope) }
    }
  end

  private

  def base_scope
    rel = ContactTracking.where(account_id: Current.account.id)
    rel = rel.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    rel = rel.where(tracking_template_id: params[:template_id]) if params[:template_id].present?
    rel = rel.where(status: params[:status]) if params[:status].present?
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

  # Fase 2 — distribución por canal (inbox), con nombre para el chart
  def by_inbox(scope)
    counts = scope.group(:inbox_id).count
    names  = Current.account.inboxes.where(id: counts.keys).pluck(:id, :name).to_h
    counts.map { |inbox_id, count| { inbox_id: inbox_id, name: names[inbox_id] || "Inbox #{inbox_id}", count: count } }
  end

  # Fase 2 — por Agente IA (tracking_template), con total y éxito (completed)
  def by_template(scope)
    with_tpl = scope.where.not(tracking_template_id: nil)
    totals   = with_tpl.group(:tracking_template_id).count
    success  = with_tpl.where(status: 'completed').group(:tracking_template_id).count
    names    = Current.account.tracking_templates.where(id: totals.keys).pluck(:id, :name).to_h
    totals.map do |tpl_id, total|
      { template_id: tpl_id, name: names[tpl_id] || "Agente IA #{tpl_id}", total: total, success: success[tpl_id] || 0 }
    end
  end

  # Fase 2 — embudo de intención (usa last_intent / appointment_at)
  def funnel(scope)
    {
      created:     scope.count,
      replied:     scope.where.not(last_intent: nil).count,
      interested:  scope.where(last_intent: %w[interested book_appointment reschedule]).count,
      appointment: scope.where.not(appointment_at: nil).count
    }
  end

  # KPIs de reglas (palabras clave de acción).
  # Dos familias: adopción (funciona aunque casi nadie use reglas) y
  # efectividad (solo sobre el subconjunto de seguimientos CON reglas).
  def rules(scope)
    with_rules = scope.where("jsonb_typeof(keyword_actions) = 'array' AND jsonb_array_length(keyword_actions) > 0")
    fired      = scope.where.not(keyword_action_fired: nil)
    by_action  = fired.group(Arel.sql("keyword_action_fired->>'action'")).count

    templates_total = Current.account.tracking_templates.count
    templates_with_rules = Current.account.tracking_templates
                                  .where("jsonb_typeof(keyword_actions) = 'array' AND jsonb_array_length(keyword_actions) > 0")
                                  .count

    top_keywords = fired.group(Arel.sql("keyword_action_fired->>'keyword'"))
                        .count
                        .sort_by { |_k, v| -v }
                        .first(5)
                        .map { |keyword, count| { keyword: keyword, count: count } }

    trackings_with_rules = with_rules.count
    fired_total = fired.count

    {
      templates_total:      templates_total,
      templates_with_rules: templates_with_rules,
      trackings_total:      scope.count,
      trackings_with_rules: trackings_with_rules,
      fired_total:          fired_total,
      fire_rate:            trackings_with_rules.zero? ? 0 : (fired_total.to_f / trackings_with_rules).round(2),
      by_action: {
        cancel:        by_action['cancel'] || 0,
        pause:         by_action['pause'] || 0,
        objective_met: by_action['objective_met'] || 0
      },
      top_keywords: top_keywords
    }
  end

  def overdue(scope)
    scope.where(status: %w[pending scheduled]).where('scheduled_for < ?', Time.current)
  end

  # Fase 3 — serie temporal: creados vs completados por día (rango o últimos 30 días)
  def timeseries(scope)
    end_date   = parse_date(params[:date_to]) || Date.current
    start_date = parse_date(params[:date_from]) || (end_date - 29)
    start_date = end_date - 89 if (end_date - start_date).to_i > 90 # tope de seguridad
    range      = start_date.beginning_of_day..end_date.end_of_day

    created   = scope.where(created_at: range).group(Arel.sql('DATE(created_at)')).count
    completed = scope.where(status: 'completed').where(updated_at: range).group(Arel.sql('DATE(updated_at)')).count

    (start_date..end_date).map do |d|
      { date: d.iso8601, created: created[d] || 0, completed: completed[d] || 0 }
    end
  end

  # Fase 3 — próximas citas agendadas
  def appointments_list(scope)
    scope.where('appointment_at >= ?', Time.current).order(appointment_at: :asc).limit(20).map do |t|
      {
        id:             t.id,
        contact_name:   t.contact&.name,
        appointment_at: t.appointment_at,
        inbox_id:       t.inbox_id,
        objective:      t.objective
      }
    end
  end

  def parse_date(value)
    value.present? ? Date.parse(value) : nil
  rescue ArgumentError
    nil
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
