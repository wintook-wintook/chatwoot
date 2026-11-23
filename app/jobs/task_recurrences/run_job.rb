# frozen_string_literal: true

# Tareas que se repiten — cada hora: crea las que tocan hoy (en la zona de cada una) y cuenta las no hechas.
# TaskRecurrences::Generator. Una que falla no detiene a las demás.
class TaskRecurrences::RunJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    due = TaskRecurrence.active.where('next_on IS NULL OR next_on <= ?', Date.current + 1)
    due.includes(:account, :user, :assignee, :case_ticket).find_each do |recurrence|
      TaskRecurrences::Generator.new(recurrence).call
    rescue StandardError => e
      Rails.logger.error("[TaskRecurrences::RunJob] #{recurrence.id}: #{e.class}: #{e.message}")
    end
  end
end
