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
    finished = TrackingCampaign.where(status: %w[draft running paused]).where(ends_at: ..now)
                               .update_all(status: 'finished', updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    started = TrackingCampaign.where(status: 'draft').where(scheduled_for: ..now)
                              .update_all(status: 'running', updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "[TrackingCampaigns::WindowJob] abiertas=#{started} finalizadas=#{finished}" if (started + finished).positive?
  end
end
