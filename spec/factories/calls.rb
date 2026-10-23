# frozen_string_literal: true

# diag/llamadas_whatsapp (F1)
FactoryBot.define do
  factory :call do
    account
    inbox { association :inbox, account: account }
    contact { association :contact, account: account }
    conversation { association :conversation, account: account, inbox: inbox, contact: contact }
    sequence(:provider_call_id) { |n| "wacid.#{n}" }
    provider { :whatsapp }
    direction { :incoming }
    status { 'ringing' }
  end
end
