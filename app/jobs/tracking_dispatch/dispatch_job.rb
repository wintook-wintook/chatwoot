# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: el despachador
# ================================================================================
# Cada minuto (config/schedule.yml). Para las cuentas con despachador
# (TRACKING_DISPATCHER_ACCOUNTS) reemplaza al ContactTrackingJob programado por seguimiento
# y a ExecutePendingJob (plan §13, pasos 2.1 a 2.4):
#
#   - recupera los tomados hace más de STALE_AFTER que nunca terminaron (proceso que murió
#     a medias): les vuelve a encolar el envío con la misma marca;
#   - da vueltas (TrackingDispatch::Claim) mientras haya vencidos y cupo, hasta ROUND_WINDOW
#     segundos, y encola un TrackingDispatch::SendJob por cada seguimiento tomado.
#
# Un lock de Redis evita que dos corridas se pisen si una tarda más de un minuto.
# ================================================================================
class TrackingDispatch::DispatchJob < ApplicationJob
  queue_as :scheduled_jobs

  LOCK_KEY = 'tracking_dispatch:round'
  ROUND_WINDOW = 45.seconds
  STALE_AFTER = 10.minutes

  def perform
    return if TrackingDispatch::Settings.account_scope == []
    return unless Redis::LockManager.new.lock(LOCK_KEY, 55.seconds)

    begin
      recover_stale
      dispatched = dispatch_rounds
      Rails.logger.info "[TrackingDispatch::DispatchJob] despachados=#{dispatched}" if dispatched.positive?
    ensure
      Redis::LockManager.new.unlock(LOCK_KEY)
    end
  end

  private

  def dispatch_rounds
    deadline = ROUND_WINDOW.from_now
    total = 0
    while Time.current < deadline
      claimed = TrackingDispatch::Claim.new.call
      break if claimed.empty?

      claimed.each { |tracking_id, token| TrackingDispatch::SendJob.perform_later(tracking_id, token) }
      total += claimed.size
    end
    total
  end

  def recover_stale
    ContactTracking.where(status: 'active').where(dispatched_at: ...STALE_AFTER.ago)
                   .pluck(:id, :dispatched_at).each do |tracking_id, dispatched_at|
      token = TrackingDispatch.token(dispatched_at)
      # Una vez cada STALE_AFTER por marca: si el job solo está atrasado en la cola, no se
      # encolan copias cada minuto (igual no harían nada: el lock y la marca las frenan).
      next unless Redis::Alfred.set("tracking_dispatch:recovered:#{tracking_id}:#{token}", 1, nx: true, ex: STALE_AFTER.to_i)

      Rails.logger.warn "[TrackingDispatch::DispatchJob] tracking #{tracking_id} tomado desde #{dispatched_at}: se reencola"
      TrackingDispatch::SendJob.perform_later(tracking_id, token)
    end
  end
end
