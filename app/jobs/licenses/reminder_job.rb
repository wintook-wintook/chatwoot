# feat/licencias (F3) — una vez al día: avisos 10 y 5 días antes de vencer (Licenses::ReminderService).
class Licenses::ReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Licenses::ReminderService.new.perform
  end
end
