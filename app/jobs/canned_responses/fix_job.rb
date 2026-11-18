# frozen_string_literal: true

# proyecto@arreglar_predefinidas — armar la propuesta de un arreglo con IA en segundo plano
# (la IA tarda de 5 a 60 segundos). La pantalla consulta el estado.
class CannedResponses::FixJob < ApplicationJob
  queue_as :default

  def perform(fix_id)
    fix = CannedResponseFix.find_by(id: fix_id)
    return unless fix&.status == 'running'
    return fix.update!(status: 'failed', error: 'stale') if fix.stale_source?

    salida, error = CannedResponses::Fix::Builders.build(CannedResponses::Fix::Context.for(fix))
    return fix.update!(status: 'failed', error: error || 'ai_failed') if salida.nil?

    fix.update!(status: 'proposed', proposal: salida[:proposal], checks: salida[:checks])
  rescue CannedResponses::Fix::Builder::NoKeyError
    fix&.update!(status: 'failed', error: 'no_key')
  rescue StandardError => e
    Rails.logger.error("[ArreglarPredefinidas] #{e.class}: #{e.message}")
    fix&.update!(status: 'failed', error: e.message.to_s.first(255))
  end
end
