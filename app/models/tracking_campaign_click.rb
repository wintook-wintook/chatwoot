# frozen_string_literal: true

# Un clic en una liga de un correo de una Campaña con Vendedor IA (TrackingCampaigns::ClickLink).
class TrackingCampaignClick < ApplicationRecord
  belongs_to :account
  belongs_to :tracking_campaign
  belongs_to :contact_tracking
  belongs_to :contact

  validates :url, presence: true, length: { maximum: 2000 }
end
