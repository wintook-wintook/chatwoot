# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas
# TrackingDeliveries::Recorder
# ================================================================================
# Registra cada envío por WhatsApp de ContactTrackingJob: aceptado por Meta (sent, con
# su Message y source_id) o rechazado al momento (failed, con el error de la respuesta).
# Corre dentro del with_lock del seguimiento, antes de que el job mueva attempt_count.
#
# Si el envío es el reenvío de un intento que falló por algo temporal, hereda el
# contador de reintentos de ese intento (ver HandleFailure#schedule_retry).
# ================================================================================
class TrackingDeliveries::Recorder
  # Mensaje solo para pasarle el contenido al proveedor de WhatsApp. Cuando Meta rechaza,
  # el proveedor hace message.update!(status: :failed, external_error: ...): con un
  # Message.new eso lo INSERTABA como mensaje fallido sin remitente y sin source_id, y
  # SendReplyJob lo volvía a mandar. Aquí update! solo asigna, para leer el error.
  def self.unsaved_message(attributes)
    message = Message.new(attributes)
    message.define_singleton_method(:update!) { |attrs| assign_attributes(attrs) }
    message
  end

  def initialize(tracking, kind:)
    @tracking = tracking
    @kind = kind
  end

  def sent(message)
    create!(message: message, source_id: message.source_id, status: 'sent', sent_at: Time.current)
  end

  def rejected(external_error)
    create!({ status: 'failed', failed_at: Time.current }.merge(TrackingDelivery.error_attributes(external_error)))
  end

  private

  def create!(attributes)
    TrackingDelivery.create!(base_attributes.merge(attributes))
  end

  def base_attributes
    {
      account_id: @tracking.account_id,
      contact_tracking: @tracking,
      tracking_campaign_id: @tracking.tracking_campaign_id,
      kind: @kind,
      attempt_number: attempt_number,
      repetition: repetition,
      retry_count: retry_count
    }
  end

  def attempt_number
    @tracking.attempt_count.to_i + 1
  end

  def repetition
    @tracking.response_adjustments_count.to_i
  end

  def retry_count
    previous = @tracking.tracking_deliveries
                        .where(attempt_number: attempt_number, repetition: repetition)
                        .where.not(next_retry_at: nil)
                        .order(:id).last
    previous ? previous.retry_count + 1 : 0
  end
end
