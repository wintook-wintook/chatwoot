# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Clase-Comercial F3
# ================================================================================
# Job: Cases::ResumePostponedJob
# Responsabilidad: el día de «retomar el», regresa la oportunidad pospuesta a
# trabajo activo (a la etapa donde estaba) y avisa al vendedor asignado.
#
# Frecuencia: diario (config/schedule.yml). Si un día no corre, al siguiente
# retoma también las atrasadas (`postponed_until <= hoy`).
# ================================================================================

class Cases::ResumePostponedJob < ApplicationJob
  queue_as :scheduled_jobs

  REASON = 'Llegó la fecha para retomarla'

  def perform
    CaseTicket.commercial
              .where(status: :waiting_on_customer)
              .where(case_tickets: { postponed_until: ..Date.current })
              .find_each { |ticket| resume(ticket) }
  end

  private

  def resume(ticket)
    ticket.resume!(reason: REASON)
    notify_assignee(ticket)
  rescue StandardError => e
    Rails.logger.error("[Cases::ResumePostponedJob] ticket ##{ticket.id}: #{e.message}")
  end

  # Reutiliza el aviso nativo de asignación (campana): no hay tipo propio de
  # «oportunidad retomada» y el vendedor solo necesita el enlace al caso.
  def notify_assignee(ticket)
    return if ticket.assignee.blank?

    NotificationBuilder.new(
      notification_type: 'case_ticket_assignment',
      user: ticket.assignee,
      account: ticket.account,
      primary_actor: ticket
    ).perform
  end
end
