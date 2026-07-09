# frozen_string_literal: true

# proyecto@ai_agent_attachments
FactoryBot.define do
  factory :ai_agent_attachment do
    sequence(:name) { |n| "archivo_#{n}" }
    tracking_template
    account { tracking_template.account }
    file { fixture_file_upload(Rails.root.join('spec/assets/sample.pdf'), 'application/pdf') }
  end
end
