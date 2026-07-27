class Webhooks::InstagramController < ActionController::API
  include MetaTokenVerifyConcern

  def events
    Rails.logger.info('Instagram webhook received events')
    if params['object'].casecmp('instagram').zero?
      ::Webhooks::InstagramEventsJob.perform_later(params.to_unsafe_hash[:entry])
      render json: :ok
    else
      Rails.logger.warn("Message is not received from the instagram webhook event: #{params['object']}")
      head :unprocessable_entity
    end
  end

  private

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
