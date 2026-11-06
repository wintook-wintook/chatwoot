# frozen_string_literal: true

# proyecto@contact_tracking — una llamada a chat/completions que falla se registra y se
# reintenta una vez.
#
# Medido el 06/11/2026 (cuenta 1128, conv 146, mensaje «¿qué precio tiene?»): el clasificador
# de ramas, KBase y el conversacional recibieron respuestas vacías en menos de un segundo; nadie
# registró el código HTTP ni el cuerpo, y el cliente se quedó sin respuesta. Lo mismo se vio en
# producción (cuenta 613, pila Fer261105: dos preguntas «Sin respuesta»).
module ContactTrackings::OpenaiRequest
  RETRY_CODES = %w[408 409 429 500 502 503 504].freeze
  RETRY_WAIT = 1.5

  module_function

  # Hace la petición; si falla por algo pasajero (sin cuerpo, 429, 5xx, timeout), espera
  # RETRY_WAIT segundos y la repite una vez. Devuelve la última respuesta (nil si las dos
  # fallaron por red).
  def perform(http, request, tag)
    response = attempt(http, request, tag)
    return response unless retry?(response)

    sleep RETRY_WAIT
    Rails.logger.info "[#{tag}] 🔁 Reintentando la llamada a OpenAI"
    attempt(http, request, tag)
  end

  def attempt(http, request, tag)
    response = http.request(request)
    unless response.code == '200' && response.body.present?
      Rails.logger.warn "[#{tag}] ⚠️ OpenAI HTTP #{response.code}: #{response.body.to_s.squish.truncate(300).presence || '(sin cuerpo)'}"
    end
    response
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn "[#{tag}] ⚠️ OpenAI sin respuesta: #{e.class}: #{e.message}"
    nil
  end

  def retry?(response)
    response.nil? || response.body.blank? || RETRY_CODES.include?(response.code)
  end
end
