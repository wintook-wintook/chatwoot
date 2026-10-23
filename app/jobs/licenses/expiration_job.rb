# feat/licencias (F3) — cada hora: vencer, promover la cola y suspender (Licenses::ExpirationService).
class Licenses::ExpirationJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Licenses::ExpirationService.new.perform
  end
end
