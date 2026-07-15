# frozen_string_literal: true

# @waba_templates
FactoryBot.define do
  factory :whatsapp_template do
    account
    channel_whatsapp
    sequence(:name) { |n| "plantilla_#{n}" }
    language { 'es' }
    category { 'UTILITY' }
    body_text { 'Hola {{1}}' }
    sample_values { { 'body' => ['Juan'] } }
    status { 'DRAFT' }
  end
end
