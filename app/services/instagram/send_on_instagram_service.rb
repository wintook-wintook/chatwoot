class Instagram::SendOnInstagramService < Base::SendOnChannelService
  include HTTParty

  pattr_initialize [:message!]

  base_uri 'https://graph.facebook.com/v11.0/me'

  # Este servicio sirve a las dos rutas: el canal nativo y el legacy (Instagram dentro de
  # un Channel::FacebookPage). Cambia el host y la credencial, no el cuerpo del mensaje.
  SUPPORTED_CHANNELS = ['Channel::Instagram', 'Channel::FacebookPage'].freeze

  # La ruta legacy se queda en la versión con la que lleva funcionando. Subirla es un
  # cambio con impacto sobre el envío de Messenger/Instagram en producción y se decide
  # aparte; este trabajo no lo toca.
  LEGACY_API_VERSION = 'v11.0'.freeze

  # El token dejó de valer. Mismo código que al leer el perfil (Instagram::MessageText).
  TOKEN_EXPIRED = 190

  private

  delegate :additional_attributes, to: :contact

  def channel_class
    channel.class
  end

  # La clase base compara contra un único channel_class; aquí hay dos válidos.
  def validate_target_channel
    raise 'Invalid channel service was called' unless SUPPORTED_CHANNELS.include?(channel.class.to_s)
  end

  def native?
    inbox.native_instagram?
  end

  def perform_reply
    if message.attachments.present?
      message.attachments.each do |attachment|
        send_message attachment_message_params(attachment)
      end
    end

    send_message message_params if message.content.present?
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account, user: message.sender).capture_exception
    # TODO : handle specific errors or else page will get disconnected
    # channel.authorization_error!
  end

  def message_params
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        text: message.content
      }
    }

    merge_human_agent_tag(params)
  end

  def attachment_message_params(attachment)
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: attachment_type(attachment),
          payload: {
            url: attachment.download_url
          }
        }
      }
    }

    merge_human_agent_tag(params)
  end

  def send_message(message_content)
    response = native? ? send_to_instagram(message_content) : send_to_facebook_page(message_content)

    process_response(response, message_content)
  end

  # Canal nativo: graph.instagram.com con el token del propio canal, sin Página de por medio.
  # `channel.instagram_id` es el IGSID con el que llegan los webhooks, pero no coincide con
  # el ID que graph.instagram.com asocia al token (Instagram API with Instagram Login usa un
  # espacio de IDs distinto). Pedirle a Meta actuar como `channel.instagram_id` devuelve
  # "The action is invalid since it's not the thread owner." Usamos `me`, igual que la ruta
  # legacy, para que Meta resuelva la identidad a partir del propio token.
  # @see https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login
  def send_to_instagram(message_content)
    HTTParty.post(
      "#{::Instagram::OauthService::GRAPH_HOST}/#{instagram_api_version}/me/messages",
      body: message_content,
      query: { access_token: channel.access_token }
    )
  end

  # Ruta legacy, sin cambios: token de la Página y appsecret_proof con el secreto de la app de Facebook.
  # @see https://developers.facebook.com/docs/messenger-platform/instagram/features/send-message
  def send_to_facebook_page(message_content)
    access_token = channel.page_access_token
    app_secret_proof = calculate_app_secret_proof(GlobalConfigService.load('FB_APP_SECRET', ''), access_token)
    query = { access_token: access_token }
    query[:appsecret_proof] = app_secret_proof if app_secret_proof

    HTTParty.post(
      "https://graph.facebook.com/#{LEGACY_API_VERSION}/me/messages",
      body: message_content,
      query: query
    )
  end

  def process_response(response, message_content)
    body = normalized_body(response)

    if body[:error].present?
      Rails.logger.error("Instagram response: #{body[:error]} : #{message_content}")
      message.status = :failed
      message.external_error = external_error(body)
    end

    message.source_id = body[:message_id] if body[:message_id].present?
    message.save!

    response
  end

  # HTTParty parsea el JSON con claves string, así que `response[:error]` (símbolo) era
  # siempre nil sobre una respuesta real: los mensajes rechazados por Meta nunca se
  # marcaban como fallidos. Normalizamos una vez y accedemos de forma indiferente.
  def normalized_body(response)
    body = response.respond_to?(:parsed_response) ? response.parsed_response : response
    return {}.with_indifferent_access unless body.is_a?(Hash)

    body.with_indifferent_access
  end

  def instagram_api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v25.0')
  end

  # Recibe el cuerpo ya normalizado por normalized_body
  def external_error(body)
    # https://developers.facebook.com/docs/instagram-api/reference/error-codes/
    error_message = body[:error][:message]
    error_code = body[:error][:code]

    # 190: el token dejó de valer (cambio de contraseña, app revocada desde Instagram…).
    # Sin marcarlo, el canal se queda enviando a la nada: los mensajes fallan uno a uno y
    # el administrador no ve el aviso de reautorizar en ningún sitio.
    channel.authorization_error! if error_code.to_i == TOKEN_EXPIRED

    "#{error_code} - #{error_message}"
  end

  def calculate_app_secret_proof(app_secret, access_token)
    Facebook::Messenger::Configuration::AppSecretProofCalculator.call(
      app_secret, access_token
    )
  end

  def attachment_type(attachment)
    return attachment.file_type if %w[image audio video file].include? attachment.file_type

    'file'
  end

  def conversation_type
    conversation.additional_attributes['type']
  end

  def sent_first_outgoing_message_after_24_hours?
    # we can send max 1 message after 24 hour window
    conversation.messages.outgoing.where('id > ?', conversation.last_incoming_message.id).count == 1
  end

  def config
    Facebook::Messenger.config
  end

  def merge_human_agent_tag(params)
    global_config = GlobalConfig.get('ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT')

    return params unless global_config['ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT']

    params[:messaging_type] = 'MESSAGE_TAG'
    params[:tag] = 'HUMAN_AGENT'
    params
  end
end
