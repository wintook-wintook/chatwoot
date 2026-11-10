# frozen_string_literal: true

# ¿Hay un agente atendiendo la conversación del caso? Para el robot de la lista y el
# tablero (junto al siguiente paso). Dos fuentes, la que contesta primero:
#   1. Seguimiento IA (AiFollowUp) vivo, del caso o de su conversación;
#   2. un agente del módulo Agentes IA (ContactTracking) vivo en su conversación, o el
#      delegado desde el caso (case_tickets.contact_tracking_id).
# Por lote (una consulta por fuente para toda la página):
#   Cases::AgentStatus.for(tickets) → { ticket_id => { state:, kind:, name:, ... } }
#   state: active (contestando) | paused (hay agente, pero ahora no contesta)
#          | none (sin agente) | no_conversation (el caso no tiene conversación)
# Cerrados y cancelados no entran (no aplica), como Cases::NextSteps.
module Cases::AgentStatus
  CLOSED = %w[closed cancelled].freeze
  TRACKING_LIVE = %w[pending scheduled active paused].freeze

  module_function

  def for(tickets)
    open = tickets.reject { |t| CLOSED.include?(t.status) }
    return {} if open.empty?

    follow_ups = live_follow_ups(open)
    trackings = live_trackings(open)
    open.to_h { |t| [t.id, status_for(t, follow_ups, trackings)] }
  end

  # Filtro de la lista: abiertos con agente vivo (with) o sin él (none).
  def with_agent(scope)
    scope.where.not(status: CLOSED).where(
      'case_tickets.id IN (:fu_cases) OR case_tickets.conversation_id IN (:fu_convs) ' \
      'OR case_tickets.conversation_id IN (:tr_convs) OR case_tickets.contact_tracking_id IN (:tr_ids)',
      fu_cases: AiFollowUp.where(status: AiFollowUp::LIVE).where.not(case_ticket_id: nil).select(:case_ticket_id),
      fu_convs: AiFollowUp.where(status: AiFollowUp::LIVE).select(:conversation_id),
      tr_convs: ContactTracking.where(status: TRACKING_LIVE).where.not(conversation_id: nil).select(:conversation_id),
      tr_ids: ContactTracking.where(status: TRACKING_LIVE).select(:id)
    )
  end

  def without_agent(scope)
    scope.where.not(status: CLOSED).where.not(id: with_agent(scope).select(:id))
  end

  def live_follow_ups(tickets)
    AiFollowUp.where(status: AiFollowUp::LIVE)
              .where('case_ticket_id IN (:ids) OR conversation_id IN (:convs)',
                     ids: tickets.map(&:id), convs: tickets.filter_map(&:conversation_id))
              .order(created_at: :desc).to_a
  end

  def live_trackings(tickets)
    ContactTracking.where(status: TRACKING_LIVE)
                   .where('conversation_id IN (:convs) OR id IN (:ids)',
                          convs: tickets.filter_map(&:conversation_id), ids: tickets.filter_map(&:contact_tracking_id))
                   .includes(:tracking_template).order(created_at: :desc).to_a
  end

  def status_for(ticket, follow_ups, trackings)
    follow_up = pick(follow_ups.select { |f| follow_up_of?(f, ticket) }) { |f| f.status == 'active' }
    return follow_up_status(follow_up) if follow_up

    tracking = pick(trackings.select { |t| tracking_of?(t, ticket) }) { |t| !t.paused? }
    return tracking_status(tracking) if tracking

    { state: ticket.conversation_id ? 'none' : 'no_conversation' }
  end

  # El que está contestando; si ninguno, el más reciente (vienen ordenados).
  def pick(list, &)
    list.find(&) || list.first
  end

  def follow_up_of?(follow_up, ticket)
    follow_up.case_ticket_id == ticket.id || same_conversation?(follow_up, ticket)
  end

  def tracking_of?(tracking, ticket)
    tracking.id == ticket.contact_tracking_id || same_conversation?(tracking, ticket)
  end

  def same_conversation?(record, ticket)
    ticket.conversation_id.present? && record.conversation_id == ticket.conversation_id
  end

  def follow_up_status(follow_up)
    { state: follow_up.status == 'active' ? 'active' : 'paused', kind: 'follow_up', name: AiFollowUp::DISPLAY_NAME,
      objective: follow_up.objective.to_s.truncate(120), attempts: follow_up.attempts, max_attempts: follow_up.max_attempts,
      next_at: follow_up.next_run_at }
  end

  def tracking_status(tracking)
    { state: tracking.paused? ? 'paused' : 'active', kind: 'agent', name: tracking.tracking_template&.name || 'Agente IA',
      objective: tracking.objective.to_s.truncate(120), attempts: tracking.attempt_count, max_attempts: tracking.max_attempts,
      next_at: (tracking.scheduled_for if tracking.pending? || tracking.scheduled?) }
  end
end
