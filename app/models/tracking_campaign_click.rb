# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_campaign_clicks
#
#  id                   :bigint           not null, primary key
#  url                  :string(2000)     not null
#  created_at           :datetime         not null
#  account_id           :bigint           not null
#  contact_id           :bigint           not null
#  contact_tracking_id  :bigint           not null
#  tracking_campaign_id :bigint           not null
#
# Indexes
#
#  index_campaign_clicks_on_campaign_and_contact           (tracking_campaign_id,contact_id)
#  index_tracking_campaign_clicks_on_account_id            (account_id)
#  index_tracking_campaign_clicks_on_tracking_campaign_id  (tracking_campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_campaign_id => tracking_campaigns.id) ON DELETE => cascade
#
class TrackingCampaignClick < ApplicationRecord
  belongs_to :account
  belongs_to :tracking_campaign
  belongs_to :contact_tracking
  belongs_to :contact

  validates :url, presence: true, length: { maximum: 2000 }
end
