# frozen_string_literal: true

# Campaña con IA · Recordar — cada mañana (y al lanzar una): mete a los contratos que ya entran en sus días
# (TrackingCampaigns::RenewEnroll).
class TrackingCampaigns::RenewEnrollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(campaign_id = nil)
    scope = campaign_id ? TrackingCampaign.where(id: campaign_id) : TrackingCampaigns::RenewEnroll.campaigns
    scope.find_each { |campaign| TrackingCampaigns::RenewEnroll.new(campaign).call }
  end
end
