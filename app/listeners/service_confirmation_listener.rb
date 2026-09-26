# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — PAGO RECIBIDO → SERVICIO EN FIRME (pieza 4, 26/09/2026)
# ================================================================================
# Con @confirmar_servicio(requiere=pago) el bot no puede saber cuándo llegó el pago: lo
# sabe una persona. Esa persona le pone a la conversación la etiqueta «pago_confirmado»
# y aquí se deja en firme el servicio apartado (se quita «[TENTATIVO]» del evento) y se
# le avisa al cliente. Ver ContactTrackings::ServiceConfirmation.
# ================================================================================

class ServiceConfirmationListener < BaseListener
  include Singleton

  def conversation_updated(event)
    conversation, _account = extract_conversation_and_account(event)
    return unless label_added?(event.data[:changed_attributes])

    ContactTrackings::PaymentConfirmedJob.perform_later(conversation.id)
  rescue StandardError => e
    Rails.logger.error("[ServiceConfirmationListener] #{e.class}: #{e.message}")
  end

  private

  def label_added?(changed)
    antes, ahora = (changed || {}).with_indifferent_access[:label_list]
    Array(ahora).include?(ContactTrackings::ServiceConfirmation::PAID_LABEL) &&
      Array(antes).exclude?(ContactTrackings::ServiceConfirmation::PAID_LABEL)
  end
end
