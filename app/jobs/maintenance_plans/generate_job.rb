# Plan-Trabajo-Campo R4 — cada mañana genera las órdenes de los mantenimientos
# que ya están dentro de su anticipación (`lead_days`).
class MaintenancePlans::GenerateJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    MaintenancePlan.due.includes(:account, :contact, :customer_asset, :case_type).find_each do |plan|
      MaintenancePlans::Generator.new(plan).call
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[MaintenancePlan] #{plan.id}: #{e.message}"
    end
  end
end
