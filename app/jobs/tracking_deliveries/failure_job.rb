# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — envío que Meta reportó como fallido por webhook
# ================================================================================
# Lo encola Message#sync_tracking_delivery. Bloquea el seguimiento (como ContactTrackingJob)
# y aplica TrackingDeliveries::HandleFailure: reintento, pausa de campaña o fallo.
# ================================================================================
class TrackingDeliveries::FailureJob < ApplicationJob
  queue_as :medium

  def perform(delivery_id)
    delivery = TrackingDelivery.find_by(id: delivery_id)
    return unless delivery&.failed?

    delivery.contact_tracking.with_lock do
      # Ya se decidió (otro webhook repetido de Meta llegó antes).
      next if delivery.reload.next_retry_at.present?

      outcome = TrackingDeliveries::HandleFailure.new(delivery, tracking: delivery.contact_tracking).perform
      Rails.logger.info "[TrackingDeliveries::FailureJob] entrega #{delivery.id} (#{delivery.error_summary}) → #{outcome}"
    end
  end
end
