# frozen_string_literal: true

# Eventos — el primer mensaje de WhatsApp que trae el código de una etiqueta NFC del
# evento liga al contacto con el evento (Events::CaptureMatcher).
class EventCaptureListener < BaseListener
  def message_created(event)
    message, = extract_message_and_account(event)
    return unless message.incoming? && message.content.to_s.match?(EventCaptureLink::CODE_PATTERN)

    Events::CaptureMatcher.new(message).call
  rescue StandardError => e
    Rails.logger.error("[EventCapture] #{e.class}: #{e.message}")
  end
end
