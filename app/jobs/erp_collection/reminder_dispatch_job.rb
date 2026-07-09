# frozen_string_literal: true

# @query_databases — corre cada hora (sidekiq-cron). Procesa los bots cobradores
# cuya hora programada (run_hour) es la actual y que aún no corrieron hoy.
class ErpCollection::ReminderDispatchJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ErpCollectionBot.due_now.find_each do |bot|
      next if bot.ran_today?

      summary = ErpCollection::ReminderService.new(bot).perform
      Rails.logger.info "[ErpCollection] bot ##{bot.id} (#{bot.name}): #{summary.inspect}"
    rescue StandardError => e
      Rails.logger.error "[ErpCollection] bot ##{bot.id} falló: #{e.message}"
    end
  end
end
