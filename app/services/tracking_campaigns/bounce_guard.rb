# frozen_string_literal: true

# Campaña con Vendedor IA por correo: si rebota demasiado (más del 5 % de lo enviado, desde 20 envíos), se pausa sola
# antes de quemar el dominio. La reanuda una persona (con la lista o el dominio revisados). Lo llama
# ContactTrackings::EmailBounce al marcar un rebote.
module TrackingCampaigns::BounceGuard
  MIN_SENT = 20
  MAX_RATE = 0.05

  module_function

  def check(campaign)
    return unless campaign&.motor2? && TrackingCampaigns::Pause::PAUSABLE_STATUSES.include?(campaign.status)

    trackings = ContactTracking.where(tracking_campaign_id: campaign.id)
    sent = trackings.where('attempt_count > 0').count
    return if sent < MIN_SENT

    bounced = trackings.where(prospect_exit: 'bounced').count
    rate = bounced.to_f / sent
    return if rate <= MAX_RATE

    TrackingCampaigns::Pause.new(campaign, reason: "Rebotó el #{(rate * 100).round}% de los correos (#{bounced} de #{sent}): " \
                                                   'revisa la lista y tu dominio antes de reanudar.').perform
  end
end
