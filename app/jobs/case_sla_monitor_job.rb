# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Job: CaseSlaMonitorJob
# Responsabilidad: Monitorea el estado SLA de todos los CaseTickets activos.
#   1. Actualiza sla_status de on_time → at_risk u overdue según tiempo transcurrido
#   2. Evalúa reglas automáticas cuando hay cambio de SLA
#   3. Cierra automáticamente tickets resueltos sin actividad por más de 72h
#
# Frecuencia: Cada 15 minutos (config/schedule.yml)
# ================================================================================

class CaseSlaMonitorJob < ApplicationJob
  queue_as :scheduled_jobs

  AUTO_CLOSE_HOURS = 72

  def perform
    Rails.logger.info '[SlaMonitor] Iniciando monitoreo de SLA'
    update_sla_statuses
    auto_close_stale_resolved
    Rails.logger.info '[SlaMonitor] Monitoreo de SLA completado'
  rescue StandardError => e
    Rails.logger.error "[SlaMonitor] Error: #{e.message}"
  end

  private

  def update_sla_statuses
    active_statuses = CaseTicket.statuses.values_at('closed', 'cancelled', 'resolved')

    CaseTicket
      .where(sla_status: [CaseTicket.sla_statuses[:on_time], CaseTicket.sla_statuses[:at_risk]])
      .where.not(status: active_statuses)
      .find_each do |ticket|
        new_sla = ticket.calculate_sla_status
        next if new_sla.to_s == ticket.sla_status

        persist_sla_change(ticket, new_sla)
      end
  end

  def persist_sla_change(ticket, new_sla)
    old_sla = ticket.sla_status
    ticket.update_columns(sla_status: CaseTicket.sla_statuses[new_sla])

    event = new_sla == :overdue ? :sla_overdue : :sla_at_risk
    ticket.case_events.create!(
      account:    ticket.account,
      event_type: event,
      origin:     :system,
      payload:    { from: old_sla, to: new_sla.to_s }
    )

    Cases::RuleEngineService.new(ticket).evaluate! if new_sla == :overdue

    Rails.logger.info "[SlaMonitor] Ticket ##{ticket.id}: #{old_sla} → #{new_sla}"
  rescue StandardError => e
    Rails.logger.error "[SlaMonitor] Error actualizando SLA en ticket ##{ticket.id}: #{e.message}"
  end

  def auto_close_stale_resolved
    cutoff = AUTO_CLOSE_HOURS.hours.ago

    CaseTicket.resolved.where('resolved_at < ?', cutoff).find_each do |ticket|
      next unless ticket.can_transition_to?(:closed)

      ticket.transition!(:closed)
      Rails.logger.info "[SlaMonitor] Ticket ##{ticket.id} auto-cerrado (#{AUTO_CLOSE_HOURS}h resuelto)"
    rescue StandardError => e
      Rails.logger.error "[SlaMonitor] Error cerrando ticket ##{ticket.id}: #{e.message}"
    end
  end
end
