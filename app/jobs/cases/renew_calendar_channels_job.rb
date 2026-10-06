# frozen_string_literal: true

# ================================================================================
# @tickets_cases F7 — Renovación de los canales de push (plan §12.6)
# ================================================================================
# Google no extiende un canal: hay que abrir uno nuevo y cerrar el viejo. Este job
# corre a diario y renueva lo que caduque en menos de 48 h. Si un canal muere sin
# renovar, no se pierde nada: la reconciliación perezosa (§5) sigue siendo la red
# de seguridad y el cambio se ve al abrir el ticket (§12.5).
# ================================================================================

class Cases::RenewCalendarChannelsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    scope = UserCalendarIntegration.where.not(push_channel_id: nil)
                                   .where(push_expires_at: ..Cases::Meetings::PushChannelService::RENEW_WINDOW.from_now)
    renewed = 0
    scope.find_each do |integration|
      renewed += 1 if Cases::Meetings::PushChannelService.new(integration).renew!
    end
    Rails.logger.info("[GestorTickets] canales de push renovados: #{renewed}")
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] RenewCalendarChannelsJob: #{e.message}")
  end
end
