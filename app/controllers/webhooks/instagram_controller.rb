class Webhooks::InstagramController < ActionController::API
  include MetaTokenVerifyConcern

  # Meta puede entregar el eco de un mensaje saliente antes de que termine la llamada que
  # lo envió, y entonces el `source_id` todavía no está guardado: el dedupe por `mid` no
  # lo reconoce y el mensaje aparece dos veces en la conversación. Un respiro de 2 s deja
  # que la respuesta de Meta se persista primero.
  ECHO_PROCESSING_DELAY = 2.seconds

  def events
    Rails.logger.info('Instagram webhook received events')
    if params['object'].casecmp('instagram').zero?
      entries = params.to_unsafe_hash[:entry]
      job = ::Webhooks::InstagramEventsJob
      job = job.set(wait: ECHO_PROCESSING_DELAY) if contains_echo_event?(entries)
      job.perform_later(entries)

      render json: :ok
    else
      Rails.logger.warn("Message is not received from the instagram webhook event: #{params['object']}")
      head :unprocessable_entity
    end
  end

  private

  def contains_echo_event?(entries)
    return false unless entries.is_a?(Array)

    entries.any? do |entry|
      Array(entry[:messaging]).any? { |messaging| messaging.dig(:message, :is_echo).present? }
    end
  end

  # El endpoint es el mismo para el canal nativo y para la ruta legacy, así que se admiten
  # los dos nombres: INSTAGRAM_VERIFY_TOKEN es el que documenta upstream para el canal
  # nativo, IG_VERIFY_TOKEN el que esta instalación ya usaba para la ruta por Página.
  # Basta con tener configurado uno de los dos.
  def valid_token?(token)
    return false if token.blank?

    [
      GlobalConfigService.load('INSTAGRAM_VERIFY_TOKEN', ''),
      GlobalConfigService.load('IG_VERIFY_TOKEN', '')
    ].compact_blank.include?(token)
  end
end
