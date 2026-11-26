# frozen_string_literal: true

# ================================================================================
# TERMINAR UNA CAMPAÑA A MANO — botón «Terminar campaña» (FinishesController)
# ================================================================================
# Programada, en curso o pausada → Terminada (finished), sin vuelta: no se reanuda.
#   - Ya no entra nadie (ends_at = ahora: TrackingCampaign#accepting_entries?; Recordar deja de inscribir).
#   - Los mensajes que faltaban por salir se cancelan (pendientes, programados y pausados).
#   - Las pláticas en curso (activas) siguen: la IA contesta a quien ya está platicando.
#   - Sus Resultados se conservan (borrar la campaña los pierde).
# Igual que cuando una campaña llega sola a su fin (TrackingCampaigns::WindowJob).
# ================================================================================
class TrackingCampaigns::Finish
  FINISHABLE = %w[saved draft running paused].freeze

  def initialize(campaign)
    @campaign = campaign
  end

  # Cuántos mensajes pendientes se cancelaron; nil si ya estaba terminada.
  def perform
    return nil unless FINISHABLE.include?(@campaign.status)

    now = Time.current
    ends = @campaign.ends_at && @campaign.ends_at < now ? @campaign.ends_at : now
    @campaign.update_columns(status: 'finished', ends_at: ends, paused_reason: nil, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    cancelled = 0
    @campaign.contact_trackings.where(status: %w[pending scheduled paused]).find_each do |tracking|
      cancelled += 1 if tracking.cancel!
    end
    Rails.logger.info "[TrackingCampaigns::Finish] campaña #{@campaign.id} terminada a mano; #{cancelled} pendientes cancelados"
    cancelled
  end
end
