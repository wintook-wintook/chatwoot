# frozen_string_literal: true

# Campaña con Vendedor IA cuya audiencia es una lista de contactos (armada desde el tablero de otra campaña:
# «con los que les interesó», «a los que no leyeron»…): los inscribe uno por uno con TrackingCampaigns::Enroll.
class TrackingCampaigns::Motor2EnrollJob < ApplicationJob
  queue_as :default

  def perform(campaign_id, contact_ids, user_id = nil)
    campaign = TrackingCampaign.find_by(id: campaign_id)
    return unless campaign

    agent = campaign.account.users.find_by(id: user_id)
    excluded = Array(campaign.audience.to_h['excluded_contact_ids']).map(&:to_i)
    campaign.account.contacts.where(id: Array(contact_ids) - excluded).find_each do |contact|
      TrackingCampaigns::Enroll.new(campaign, contact, source: 'batch', agent: agent).call
    rescue StandardError => e
      Rails.logger.error("[Motor2EnrollJob] campaña #{campaign_id}, contacto #{contact.id}: #{e.message}")
    end
  end
end
