FactoryBot.define do
  factory :license_plan do
    sequence(:name) { |n| "Plan #{n}" }
    duration_days { 30 }
    default_max_agents { 5 }
    license_type { :paid }
  end
end
