# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — ABRIR Y CERRAR CAMPAÑAS POR SU VENTANA
# ================================================================================
# Plan: docs/automatizacion_campanas_plan.md (§6). Cada 5 minutos (config/schedule.yml):
#
#   Programada (draft) cuyo inicio ya llegó        → En curso (running)
#   Programada, en curso o pausada cuyo fin pasó   → Finalizada (finished)
#
# Es el estado que se ve en la pantalla. Las inscripciones no dependen de este job:
# TrackingCampaign#accepting_entries? mira la hora del fin en el momento, así que una
# automatización que dispara un minuto después del fin ya queda fuera aunque el job todavía
# no haya pasado. Los ya inscritos terminan su conversación: cerrar la campaña no toca sus
# seguimientos.
# ================================================================================
class TrackingCampaigns::WindowJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(now = Time.current)
    closing = TrackingCampaign.where(status: %w[draft running paused]).where(ends_at: ..now)
    ids = closing.pluck(:id)
    finished = closing.update_all(status: 'finished', updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    cancel_pending_motor2(ids)
    started = TrackingCampaign.where(status: 'draft').where(scheduled_for: ..now)
                              .update_all(status: 'running', updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "[TrackingCampaigns::WindowJob] abiertas=#{started} finalizadas=#{finished}" if (started + finished).positive?
  end

  private

  # Campaña con Vendedor IA que llegó a su fin: los toques que faltaban ya no salen (antes seguían después del fin).
  # Las pláticas en curso (activas) siguen: el vendedor contesta a quien ya respondió.
  def cancel_pending_motor2(ids)
    return if ids.empty?

    ContactTracking.joins(:tracking_campaign).where(tracking_campaign_id: ids, status: %w[pending scheduled], tracking_campaigns: { engine: '2' })
                   .find_each(&:cancel!)
  end
end
