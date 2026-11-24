# frozen_string_literal: true

# Campaña con Vendedor IA cuya audiencia es una lista de contactos (armada desde el tablero de otra campaña:
# «con los que les interesó», «a los que no leyeron»…): los inscribe uno por uno con TrackingCampaigns::Enroll.
class TrackingCampaigns::Motor2EnrollJob < ApplicationJob
  queue_as :default

  # contact_ids nil: los de la audiencia guardada (así una lista de miles no viaja en el argumento del job). Si Sidekiq
  # se reinicia a media inscripción, correrlo otra vez es seguro: los ya inscritos quedan «already_enrolled».
  def perform(campaign_id, contact_ids = nil, user_id = nil)
    campaign = TrackingCampaign.find_by(id: campaign_id)
    return unless campaign

    agent = campaign.account.users.find_by(id: user_id)
    campaign.account.contacts.where(id: pending_ids(campaign, contact_ids)).find_each do |contact|
      TrackingCampaigns::Enroll.new(campaign, contact, source: 'batch', agent: agent).call
    rescue StandardError => e
      Rails.logger.error("[Motor2EnrollJob] campaña #{campaign_id}, contacto #{contact.id}: #{e.message}")
    end
  end

  private

  # Los de la audiencia (o los que se pasaron), sin los excluidos ni los que ya tienen su inscripción.
  def pending_ids(campaign, contact_ids)
    audience = campaign.audience.to_h
    ids = contact_ids.nil? ? Array(audience['contact_ids']) : Array(contact_ids)
    ids.map(&:to_i) - Array(audience['excluded_contact_ids']).map(&:to_i) - campaign.entries.pluck(:contact_id)
  end
end
