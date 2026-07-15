# frozen_string_literal: true

# @campanas_vendedor
FactoryBot.define do
  factory :tracking_campaign do
    account
    sequence(:name) { |n| "Campaña #{n}" }
    objective { 'Reactivar prospectos fríos' }
    scheduled_for { 1.day.from_now }
    status { 'running' }
  end
end
