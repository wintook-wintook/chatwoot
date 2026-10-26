# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_source do
    account
    source_type { 'canned_response' }
    sequence(:name) { |n| "Knowledge Source #{n}" }
    status { 'active' }
  end
end
