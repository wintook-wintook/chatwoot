# frozen_string_literal: true

# proyecto@contact_tracking
FactoryBot.define do
  factory :contact_tracking do
    account
    contact
    inbox
    objective { 'Re-enganchar al contacto que no respondió' }
    scheduled_for { 1.day.from_now }
    max_attempts { 3 }
    attempt_count { 0 }
    status { 'pending' }
  end
end
