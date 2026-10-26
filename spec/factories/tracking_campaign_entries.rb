# frozen_string_literal: true

# proyecto@automatizacion_campanas
FactoryBot.define do
  factory :tracking_campaign_entry do
    tracking_campaign
    account { tracking_campaign.account }
    contact { association :contact, account: tracking_campaign.account }
    source { 'batch' }
    status { 'enrolled' }
  end
end
