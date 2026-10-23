# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — reanuda los seguimientos que pausó la campaña
# ================================================================================
# Lo encola TrackingCampaigns::Resume. Cada seguimiento se reprograma a 1 minuto más un
# segundo por cada uno anterior. Si mientras tanto la campaña se volvió a pausar, no hace
# nada: esos seguimientos esperan la siguiente reanudación.
# ================================================================================
class TrackingCampaigns::ResumeJob < ApplicationJob
  queue_as :default

  def perform(campaign_id)
    campaign = TrackingCampaign.find_by(id: campaign_id)
    return if campaign.nil? || campaign.status == 'paused'

    start = 1.minute.from_now
    campaign.contact_trackings.where(status: 'paused', paused_by_campaign: true).order(:id).each_with_index do |tracking, index|
      next tracking.update_column(:paused_by_campaign, false) if tracking.resume!(start + index.seconds) # rubocop:disable Rails/SkipsModelValidations

      Rails.logger.error "[TrackingCampaigns::ResumeJob] seguimiento #{tracking.id} no se reanudó: #{tracking.errors.full_messages.to_sentence}"
    end
  end
end
