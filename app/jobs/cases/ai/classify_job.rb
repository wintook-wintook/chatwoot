# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3B — Clasificación automática (asíncrona)
# ================================================================================
# Job: Cases::Ai::ClassifyJob
#
# Se encola tras crear un ticket. Lee el modo de la acción `classify`:
#   - 'off'     → no hace nada
#   - 'auto'    → aplica la clasificación sugerida (solo en campos aún vacíos),
#                 recalcula prioridad por matriz y registra evento ai_classified
#   - 'suggest' → guarda la sugerencia en ticket.metadata['ai_classification'] y
#                 registra evento ai_suggested (la UI la muestra para aprobar)
#
# Nunca bloquea ni rompe la creación del ticket (corre en background, con rescue).
# ================================================================================

class Cases::Ai::ClassifyJob < ApplicationJob
  queue_as :low

  def perform(ticket_id)
    ticket = CaseTicket.find_by(id: ticket_id)
    return if ticket.nil?

    config = CaseAiConfig.for_account(ticket.account)
    mode   = config.mode_for(:classify)
    return if mode == 'off'

    result = Cases::Ai::Classifier.new(account: ticket.account).classify(ticket)
    return if result.blank?

    mode == 'auto' ? apply!(ticket, result) : suggest!(ticket, result)
  rescue StandardError => e
    Rails.logger.error("[Cases::Ai::ClassifyJob] #{e.message}")
  end

  private

  # Aplica solo los campos que el ticket aún no tiene definidos (no pisa decisiones
  # humanas). La prioridad se recalcula por la matriz impacto×urgencia del modelo.
  def apply!(ticket, result)
    attrs = {}
    attrs[:ticket_kind]         = result['ticket_kind']         if result['ticket_kind'] && ticket.ticket_kind.blank?
    attrs[:impact]              = result['impact']              if result['impact'] && ticket.impact.blank?
    attrs[:urgency]             = result['urgency']             if result['urgency'] && ticket.urgency.blank?
    attrs[:affected_service_id] = result['affected_service_id'] if result['affected_service_id'] && ticket.affected_service_id.blank?
    attrs[:category_id]         = result['category_id']         if result['category_id'] && ticket.category_id.blank?

    store_suggestion(ticket, result, applied: true)
    ticket.update!(attrs) if attrs.any?

    ticket.case_events.create!(
      account:    ticket.account,
      event_type: :ai_classified,
      origin:     :system,
      payload:    event_payload(result).merge('applied' => attrs.keys.map(&:to_s))
    )
  end

  def suggest!(ticket, result)
    store_suggestion(ticket, result, applied: false)
    ticket.case_events.create!(
      account:    ticket.account,
      event_type: :ai_suggested,
      origin:     :system,
      payload:    event_payload(result)
    )
  end

  # Guarda la sugerencia en metadata para que la UI la muestre/aplique.
  def store_suggestion(ticket, result, applied:)
    ticket.update_columns(
      metadata: ticket.metadata.merge(
        'ai_classification' => result.merge('applied' => applied, 'suggested_at' => Time.current.iso8601)
      )
    )
  end

  def event_payload(result)
    result.slice('ticket_kind', 'impact', 'urgency', 'affected_service_id', 'category_id', 'confidence', 'reasoning')
  end
end
