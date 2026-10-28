# frozen_string_literal: true

# prospeccion P4 (§10.11) — recalcula la puntuación de los prospectos.
#   sin campaign_id: todas las campañas de Prospección no terminadas (diario, schedule.yml):
#                    cubre etiquetas que cambiaron y los 30 días sin responder
#   con campaign_id: una campaña (al guardar sus pesos y reglas)
class TrackingCampaigns::ProspectScoreJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(campaign_id = nil)
    campaigns = TrackingCampaign.where(purpose: 'prospecting')
    campaigns = campaign_id ? campaigns.where(id: campaign_id) : campaigns.where.not(status: 'completed')
    campaigns.find_each { |campaign| rescore(campaign) }
  end

  private

  def rescore(campaign)
    config = TrackingCampaigns::ScoringConfig.for(campaign)
    campaign.contact_trackings.includes(:contact, :tracking_campaign).find_each do |tracking|
      TrackingCampaigns::ProspectScore.call(tracking, config)
    rescue StandardError => e
      Rails.logger.error("[ProspectScore] tracking ##{tracking.id}: #{e.message}")
    end
  end
end
