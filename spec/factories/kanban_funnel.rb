# frozen_string_literal: true

FactoryBot.define do
  factory :kanban_type_process do
    account
    sequence(:process_name) { |n| "Tablero #{n}" }
  end

  factory :kanban_process do
    kanban_type_process
    account { kanban_type_process.account }
    sequence(:type_process_name) { |n| "Columna #{n}" }
    sequence(:position) { |n| n }
  end
end
