# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3F — Escaneo de seguimientos automáticos (programado)
# ================================================================================
# Job: Cases::Ai::FollowUpScanJob
#
# Recorre las cuentas con la acción `follow_up` activa y, para los tickets que
# llevan demasiado tiempo en espera del cliente sin actividad, redacta un borrador
# de seguimiento (Cases::Ai::FollowUp) y lo guarda en metadata['ai_follow_up'] +
# registra un evento `ai_followup`. NO envía nada al cliente (seguridad): el agente
# revisa y envía. Pensado para correr cada hora desde schedule.yml.
# ================================================================================

class Cases::Ai::FollowUpScanJob < ApplicationJob
  queue_as :scheduled_jobs

  STALE_HOURS = 24          # horas en espera sin actividad para sugerir seguimiento
  PER_ACCOUNT_LIMIT = 20    # tope por corrida para no abusar de la API

  def perform
    CaseAiConfig.where(enabled: true).find_each do |config|
      next unless config.active?(:follow_up)

      scan_account(config.account)
    rescue StandardError => e
      Rails.logger.error("[Cases::Ai::FollowUpScanJob] account #{config.account_id}: #{e.message}")
    end
  end

  private

  def scan_account(account)
    service = Cases::Ai::FollowUp.new(account: account)
    return unless service.available?

    stale_tickets(account).each { |ticket| draft_for(ticket, service) }
  end

  # Tickets en espera del cliente, sin actividad reciente y sin un seguimiento ya pendiente.
  def stale_tickets(account)
    account.case_tickets
           .where(status: :waiting_on_customer)
           .where('updated_at < ?', STALE_HOURS.hours.ago)
           .where("COALESCE(metadata->'ai_follow_up'->>'status', '') <> 'pending'")
           .order(updated_at: :asc)
           .limit(PER_ACCOUNT_LIMIT)
  end

  def draft_for(ticket, service)
    message = service.draft(ticket)
    return if message.blank?

    ticket.update_columns(
      metadata: ticket.metadata.merge(
        'ai_follow_up' => { 'status' => 'pending', 'message' => message, 'drafted_at' => Time.current.iso8601 }
      )
    )
    ticket.case_events.create!(
      account: ticket.account, event_type: :ai_followup, origin: :system,
      payload: { auto: true }
    )
  end
end
