# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Message → TrackingDelivery
# ================================================================================
# El webhook de estado de WhatsApp (Whatsapp::IncomingMessageBaseService#process_statuses)
# ya actualiza message.status y external_error. Aquí ese cambio se copia al envío del
# seguimiento, si el mensaje es uno. Si quedó fallido, FailureJob decide el reintento.
# No se toca el procesamiento de webhooks del core.
# ================================================================================
module TrackingDeliverySync
  extend ActiveSupport::Concern

  included do
    after_update_commit :sync_tracking_delivery, if: -> { saved_change_to_status? && outgoing? }
  end

  private

  def sync_tracking_delivery
    delivery = TrackingDelivery.find_by(message_id: id)
    return unless delivery&.apply_message_status!(status, external_error)

    TrackingDeliveries::FailureJob.perform_later(delivery.id) if delivery.failed?
  rescue StandardError => e
    Rails.logger.error "[TrackingDeliverySync] mensaje #{id}: #{e.message}"
  end
end
