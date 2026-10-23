FactoryBot.define do
  factory :account_license do
    account
    name { 'Profesional' }
    license_type { :paid }
    status { :active }
    max_agents { 5 }
    duration_days { 30 }
    starts_at { Time.current }
    expires_at { 30.days.from_now }
  end
end
