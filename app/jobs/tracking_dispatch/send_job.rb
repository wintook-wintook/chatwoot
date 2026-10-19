# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: envío de un seguimiento tomado por el despachador
# ================================================================================
# Lo encola TrackingDispatch::DispatchJob con la marca de la vuelta (dispatched_at). Usa las
# mismas decisiones de envío que ContactTrackingJob (#deliver y #after_send), pero en tres
# pasos, para que OpenAI y Meta NO corran dentro del bloqueo de la fila (plan §13, 2.5):
#
#   1. sin bloqueo: ¿sigue tomado con esta marca? (si no, otro ya lo resolvió)
#   2. sin bloqueo: decidir y enviar (#deliver). Cada envío queda en TrackingDelivery en su
#      propia transacción, en cuanto Meta responde.
#   3. con bloqueo, corto: avanzar el intento (#after_send) y soltar la marca.
#
# Nadie más lo envía mientras tanto: el despachador solo toma pending / scheduled, y un lock
# de Redis por seguimiento evita que dos SendJob de la misma marca corran juntos.
#
# Si en el paso 2 alguien lo cambió (el cliente respondió y el analizador lo pausó o lo
# reagendó, un agente lo canceló...), en el paso 3 se respeta ese cambio: solo se cuenta el
# intento enviado.
#
# Recuperación: si el proceso muere a medias, el despachador vuelve a encolar este job con la
# misma marca. Si el envío de esa marca ya quedó registrado, no se vuelve a mandar: solo se
# termina el paso 3.
# ================================================================================
class TrackingDispatch::SendJob < ContactTrackingJob
  queue_as :campaign_dispatch

  LOCK_TTL = 5.minutes

  def perform(tracking_id, token)
    lock_key = "tracking_dispatch:send:#{tracking_id}"
    return unless Redis::LockManager.new.lock(lock_key, LOCK_TTL)

    begin
      tracking = ContactTracking.find_by(id: tracking_id)
      return unless claimed?(tracking, token)
      return release(tracking) if tracking.tracking_campaign&.status == 'paused'

      tracking.update_columns(last_attempt_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      result = previous_send(tracking) || deliver(tracking)
      finish(tracking, token, result)
    rescue StandardError => e
      fail_claimed(tracking, token, e)
    ensure
      Redis::LockManager.new.unlock(lock_key)
    end
  end

  private

  def claimed?(tracking, token)
    tracking&.active? && TrackingDispatch.token(tracking.dispatched_at) == token
  end

  # La campaña se pausó después de tomarlo: vuelve a la fila, sin enviar. El despachador no
  # toma seguimientos de campañas pausadas; al reanudarla sale solo.
  def release(tracking)
    tracking.update_columns(status: 'scheduled', dispatched_at: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Recuperación: el envío de esta marca ya salió (o Meta ya lo rechazó). true / false como
  # #deliver; nil si no hay nada registrado y hay que enviar.
  def previous_send(tracking)
    delivery = tracking.tracking_deliveries
                       .where(attempt_number: tracking.attempt_count + 1, repetition: tracking.response_adjustments_count)
                       .where(created_at: tracking.dispatched_at..)
                       .order(:id).last
    return if delivery.nil?

    Rails.logger.warn "[TrackingDispatch::SendJob] tracking #{tracking.id}: envío ya registrado (#{delivery.id}), no se reenvía"
    return true unless delivery.failed?

    @rejected_delivery = delivery
    false
  end

  def finish(tracking, token, result)
    tracking.with_lock do
      tracking.reload
      if result == :aborted
        # #deliver ya lo dejó fallido (ventana cerrada sin plantilla)
      elsif claimed?(tracking, token)
        after_send(tracking, result)
      elsif result
        count_attempt(tracking)
      end
      tracking.update_columns(dispatched_at: nil) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # Lo cambiaron mientras se enviaba: se respeta su estado y solo se cuenta el intento.
  def count_attempt(tracking)
    counter = tracking.auto_retry_mode? ? :response_adjustments_count : :attempt_count
    tracking.increment!(counter) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "[TrackingDispatch::SendJob] tracking #{tracking.id} cambió durante el envío (#{tracking.status}); se contó el intento"
  end

  def fail_claimed(tracking, token, error)
    Rails.logger.error "[TrackingDispatch::SendJob] tracking #{tracking&.id}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
    return unless claimed?(tracking&.reload, token)

    tracking.update_columns(status: 'failed', last_error: error.message.truncate(250), dispatched_at: nil, # rubocop:disable Rails/SkipsModelValidations
                            updated_at: Time.current)
  end
end
