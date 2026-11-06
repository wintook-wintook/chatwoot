# frozen_string_literal: true

# Seguimiento IA — cada minuto (config/schedule.yml): los seguimientos a los que ya les toca
# escribirle al cliente.
class AiFollowUps::DueJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AiFollowUp.due.limit(200).pluck(:id).each { |id| AiFollowUps::RunJob.perform_later(id, 'scheduled') }
  end
end
