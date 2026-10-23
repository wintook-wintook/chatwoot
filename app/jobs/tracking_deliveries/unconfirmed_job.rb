# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — envíos que Meta aceptó pero nunca confirmó
# ================================================================================
# Cada hora (config/schedule.yml): lo que lleva más de 24 h en 'sent' sin delivered/read
# pasa a 'unconfirmed'. NO se reenvía: si sí llegó, el contacto lo recibiría dos veces.
# Se cuenta aparte en la campaña. Un delivered/read tardío lo sigue actualizando.
# ================================================================================
class TrackingDeliveries::UnconfirmedJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    count = TrackingDelivery.where(status: 'sent').where(sent_at: ...TrackingDelivery::UNCONFIRMED_AFTER.ago)
                            .update_all(status: 'unconfirmed', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "[TrackingDeliveries::UnconfirmedJob] sin confirmar=#{count}" if count.positive?
  end
end
