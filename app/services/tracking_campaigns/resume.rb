# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — REANUDAR UNA CAMPAÑA PAUSADA
# ================================================================================
# Botón "Reanudar campaña" del detalle (POST tracking_campaigns/:id/resume), después de
# corregir lo que la pausó (ver TrackingCampaigns::Pause).
#
#   - La campaña vuelve a Programada / En curso según su inicio, o a Finalizada si su
#     ventana ya terminó mientras estaba pausada.
#   - Los seguimientos que pausó la campaña (paused_by_campaign) se reanudan en background
#     (TrackingCampaigns::ResumeJob), escalonados un segundo para no salir todos juntos.
#     Los pausados a mano o por una regla se quedan como están.
#
# Uso: TrackingCampaigns::Resume.new(campaign).call # => { campaign:, trackings: } | { error: }
# ================================================================================
class TrackingCampaigns::Resume
  def initialize(campaign)
    @campaign = campaign
  end

  def call
    paused_trackings = @campaign.contact_trackings.where(status: 'paused', paused_by_campaign: true).count
    return { error: 'La campaña no está pausada.' } unless @campaign.status == 'paused' || paused_trackings.positive?

    reopen_campaign if @campaign.status == 'paused'
    TrackingCampaigns::ResumeJob.perform_later(@campaign.id) if paused_trackings.positive?
    { campaign: @campaign, trackings: paused_trackings }
  end

  private

  def reopen_campaign
    now = Time.current
    status = if @campaign.ends_at && @campaign.ends_at <= now
               'finished'
             else
               TrackingCampaign.status_for(@campaign.scheduled_for || now, now)
             end
    @campaign.update_columns(status: status, paused_reason: nil, paused_at: nil, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
  end
end
