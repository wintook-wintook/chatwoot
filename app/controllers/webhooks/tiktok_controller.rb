# Webhook de mensajes directos de TikTok.
#
# A diferencia de Meta, TikTok no hace handshake de verificación: firma CADA petición con
# HMAC-SHA256 sobre "<timestamp>.<cuerpo>" usando el App Secret, y la cabecera trae los dos
# valores. Por eso aquí solo hay POST y no hay acción `verify`.
# @see https://business-api.tiktok.com/portal/docs?id=1832190670631937
class Webhooks::TiktokController < ActionController::API
  before_action :verify_signature!

  # Ventana de antigüedad aceptada para una petición firmada. Acota el margen para
  # reenviar una petición capturada.
  MAX_SIGNATURE_AGE = 5.seconds

  # Meta y TikTok comparten el mismo problema: el eco de un mensaje saliente puede llegar
  # antes de que termine la llamada que lo envió, y entonces el source_id todavía no está
  # guardado. Un respiro de 2 s deja que se persista primero.
  ECHO_PROCESSING_DELAY = 2.seconds

  def events
    event = JSON.parse(request_payload)

    job = ::Webhooks::TiktokEventsJob
    job = job.set(wait: ECHO_PROCESSING_DELAY) if echo_event?
    job.perform_later(event)

    head :ok
  rescue JSON::ParserError
    Rails.logger.warn('[TikTok] webhook con cuerpo que no es JSON')
    head :bad_request
  end

  private

  # Se lee una sola vez: el cuerpo crudo es lo que se firma, y request.body no se puede
  # releer.
  def request_payload
    @request_payload ||= request.body.read
  end

  def verify_signature!
    received_timestamp, received_signature = extract_signature_parts(request.headers['Tiktok-Signature'])
    return head :unauthorized if client_secret.blank? || received_timestamp.blank? || received_signature.blank?
    return head :unauthorized unless signature_matches?(received_timestamp, received_signature)
    return head :unauthorized if Time.current.to_i - received_timestamp > MAX_SIGNATURE_AGE.to_i

    true
  end

  def signature_matches?(received_timestamp, received_signature)
    computed = OpenSSL::HMAC.hexdigest('SHA256', client_secret, "#{received_timestamp}.#{request_payload}")
    # Comparación en tiempo constante: comparar con == filtra información por el tiempo.
    ActiveSupport::SecurityUtils.secure_compare(computed, received_signature)
  end

  # Cabecera con la forma "t=1700000000,s=abc123"
  def extract_signature_parts(signature_header)
    return [nil, nil] if signature_header.blank?

    parts = signature_header.split(',').filter_map { |part| part.split('=', 2) }.to_h
    [parts['t'].presence&.to_i, parts['s'].presence]
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('TIKTOK_APP_SECRET', nil)
  end

  def echo_event?
    params[:event] == 'im_send_msg'
  end
end
