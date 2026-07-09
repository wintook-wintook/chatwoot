# frozen_string_literal: true

# proyecto@tracking_templates
FactoryBot.define do
  factory :tracking_template do
    sequence(:name) { |n| "Agente IA #{n}" }
    objective { 'Re-enganchar al contacto que no respondió' }
    account
  end
end
