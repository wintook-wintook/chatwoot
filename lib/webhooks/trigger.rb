class Webhooks::Trigger
  SUPPORTED_ERROR_HANDLE_EVENTS = %w[message_created message_updated].freeze

  def initialize(url, payload, webhook_type, method, headers)
    @url = url
    @payload = payload
    @webhook_type = webhook_type
    @method = method
    @headers = headers
  end

  def self.execute(url, payload, webhook_type, method = :post, headers = { content_type: :json, accept: :json })
    new(url, payload, webhook_type, method, headers).execute
  end

  # La URL publica de esta instancia: lo que viaja en los payloads como instance_url.
  # Mismo orden de resolucion que el resto del repo (ENV y, si no, la config global).
  #
  # Es publica y de clase porque BotSeller::Dispatcher manda su webhook con Net::HTTP
  # propio, sin pasar por aqui, y tiene que poner EL MISMO valor. Una segunda lectura
  # de FRONTEND_URL alli seria una copia que puede divergir.
  def self.instance_url
    ENV.fetch('FRONTEND_URL', nil).presence || GlobalConfigService.load('FRONTEND_URL', nil)
  end

  def execute
    perform_request
  rescue StandardError => e
    handle_error(e)
    Rails.logger.warn "Exception: Invalid webhook URL #{@url} : #{e.message}"
  end

  private

  def perform_request
    body = payload_with_instance
    Rails.logger.debug { "Webhook Trigger @method: #{@method} @url #{@url}  @payload #{body.to_json} @headers #{@headers}" }
    RestClient::Request.execute(
      method: @method,
      url: @url,
      payload: body.to_json,
      headers: @headers,
      timeout: ENV.fetch('WEBHOOKS_TRIGGER_TIMEOUT', '5').to_i
    )
  end

  # CAMBIO LOCAL (no upstream): el payload no llevaba nada que dijera de que instancia
  # de Chatwoot venia el evento -- solo account: {id, name} en algunos eventos, y ni eso
  # en los de conversacion. Un receptor que atiende a mas de una instancia no podia
  # distinguirlas, ni armar el enlace a la conversacion.
  #
  # Se inyecta aqui y no en cada `webhook_data` porque este es el unico punto por el que
  # pasan TODOS los envios: webhooks de cuenta, del inbox API, de automatizaciones, de
  # macros y los installation events.
  #
  # No es prueba de origen: estos webhooks no van firmados, asi que el receptor no debe
  # tratar este campo como autenticacion.
  def payload_with_instance
    return @payload unless @payload.is_a?(Hash)
    return @payload if base_url.blank?

    # merge, no mutacion: `should_handle_error?` y `message_id` leen @payload despues.
    @payload.merge(instance_url: base_url)
  end

  def base_url
    return @base_url if defined?(@base_url)

    @base_url = self.class.instance_url
  end

  def handle_error(error)
    return unless should_handle_error?
    return unless message

    update_message_status(error)
  end

  def should_handle_error?
    @webhook_type == :api_inbox_webhook && SUPPORTED_ERROR_HANDLE_EVENTS.include?(@payload[:event])
  end

  def update_message_status(error)
    message.update!(status: :failed, external_error: error.message)
  end

  def message
    return if message_id.blank?

    @message ||= Message.find_by(id: message_id)
  end

  def message_id
    @payload[:id]
  end
end
