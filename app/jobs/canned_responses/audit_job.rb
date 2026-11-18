# frozen_string_literal: true

# proyecto@auditoria_predefinidas — «Auditar» toda la cuenta (CannedResponses::Audit::Runner#all).
# La corrida (CannedResponseAudit) la crea el controlador; aquí se cierra con lo que pasó.
class CannedResponses::AuditJob < ApplicationJob
  queue_as :low

  def perform(audit_id)
    audit = CannedResponseAudit.find_by(id: audit_id)
    return unless audit&.status == 'running'

    stats = CannedResponses::Audit::Runner.new(audit.account).all
    audit.update!(status: 'done', stats: stats, finished_at: Time.current)
  rescue CannedResponses::Audit::Runner::NoKeyError
    audit&.update!(status: 'failed', error: 'no_key', finished_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[AuditoríaPredefinidas] #{e.class}: #{e.message}")
    audit&.update!(status: 'failed', error: e.message.to_s.first(255), finished_at: Time.current)
  end
end
