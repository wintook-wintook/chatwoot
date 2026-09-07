# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_item do
    account
    knowledge_source
    source_type { 'canned_response' }
    sequence(:source_id) { |n| n }
    sequence(:title) { |n| "Respuesta predefinida #{n}" }
    content { 'Contenido de prueba de la respuesta predefinida.' }
    metadata { {} }
  end
end
