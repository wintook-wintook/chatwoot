class Facebook::SendOnFacebookService < Base::SendOnChannelService
  # Límites de Meta para las respuestas rápidas. Pasarse NO degrada el mensaje: Meta
  # rechaza el envío entero, así que el cliente no recibiría ni el texto. Por eso se
  # recorta aquí en vez de confiar en quien compone el mensaje.
  # @see https://developers.facebook.com/docs/messenger-platform/send-messages/quick-replies
  MAX_QUICK_REPLIES = 13
  MAX_QUICK_REPLY_TITLE = 20

  private

  def channel_class
    Channel::FacebookPage
  end

  def perform_reply
    send_message_to_facebook fb_text_message_params if message.content.present?

    # OJO: aquí había un `retryable(tries: 3, ...)` que llamaba a un método inexistente —
    # la gema `retryable` nunca estuvo en el Gemfile. Desde que se introdujo (3cd3f4d6,
    # septiembre de 2024) enviar un adjunto por Messenger lanzaba NoMethodError, que
    # además escapa del rescue de abajo: el adjunto no llegaba y el mensaje ni siquiera
    # quedaba marcado como fallido.
    if message.attachments.present?
      message.attachments.each do |attachment|
        send_message_to_facebook fb_attachment_message_params(attachment)
      end
    end
  rescue Facebook::Messenger::FacebookError => e
    # TODO : handle specific errors or else page will get disconnected
    handle_facebook_error(e)
    message.update!(status: :failed, external_error: e.message)
  end

  def send_message_to_facebook(delivery_params)
    parsed_result = deliver_message(delivery_params)
    return if parsed_result.nil?

    if parsed_result['error'].present?
      message.update!(status: :failed, external_error: external_error(parsed_result))
      Rails.logger.info "Facebook::SendOnFacebookService: Error sending message to Facebook : Page - #{channel.page_id} : #{parsed_result}"
    end
    message.update!(source_id: parsed_result['message_id']) if parsed_result['message_id'].present?
  end

  # Cuando Meta contesta algo que no es JSON (página de error, gateway caído) o no
  # contesta, la excepción no es un Facebook::Messenger::FacebookError, así que escapaba
  # del rescue de perform_reply: el mensaje se quedaba como enviado, sin marca de fallo, y
  # Sidekiq reintentaba el job a ciegas. Ahora se marca fallido y no se reintenta, que es
  # lo que evita mandarle el mismo mensaje dos veces al cliente.
  def deliver_message(delivery_params)
    result = Facebook::Messenger::Bot.deliver(delivery_params, page_id: channel.page_id)
    JSON.parse(result)
  rescue JSON::ParserError
    fail_message('Facebook was unable to process this request')
    Rails.logger.error "Facebook::SendOnFacebookService: Error parsing JSON response from Facebook : Page - #{channel.page_id}"
    nil
  rescue Net::OpenTimeout, Net::ReadTimeout
    fail_message('Request timed out, please try again later')
    Rails.logger.error "Facebook::SendOnFacebookService: Timeout error sending message to Facebook : Page - #{channel.page_id}"
    nil
  end

  def fail_message(reason)
    message.update!(status: :failed, external_error: reason)
  end

  def fb_text_message_params
    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: fb_text_message_payload,
      messaging_type: 'MESSAGE_TAG',
      tag: 'ACCOUNT_UPDATE'
    }
  end

  # Una pregunta con opciones (`input_select`, la que hacen los bots) viajaba a Messenger
  # como texto plano: la pregunta llegaba y las opciones no. WhatsApp y Telegram ya las
  # pintaban como botones; esto pone a Messenger a la par.
  def fb_text_message_payload
    return { text: message.content } unless quick_replies?

    { text: message.content, quick_replies: quick_replies }
  end

  def quick_replies?
    message.content_type == 'input_select' && message.content_attributes['items'].present?
  end

  def quick_replies
    message.content_attributes['items'].first(MAX_QUICK_REPLIES).map do |item|
      {
        content_type: 'text',
        # `value` es el identificador y `title` lo que ve el cliente, igual que en
        # WhatsApp (`reply.id`) y en Telegram (`callback_data`).
        payload: item['value'].presence || item['title'],
        title: item['title'].to_s.truncate(MAX_QUICK_REPLY_TITLE)
      }
    end
  end

  def external_error(response)
    # https://developers.facebook.com/docs/graph-api/guides/error-handling/
    error_message = response['error']['message']
    error_code = response['error']['code']

    "#{error_code} - #{error_message}"
  end

  def fb_attachment_message_params(attachment)
    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: attachment_type(attachment),
          payload: {
            url: attachment.download_url
          }
        }
      },
      messaging_type: 'MESSAGE_TAG',
      tag: 'ACCOUNT_UPDATE'
    }
  end

  def attachment_type(attachment)
    return attachment.file_type if %w[image audio video file].include? attachment.file_type

    'file'
  end

  def sent_first_outgoing_message_after_24_hours?
    # we can send max 1 message after 24 hour window
    conversation.messages.outgoing.where('id > ?', conversation.last_incoming_message.id).count == 1
  end

  def handle_facebook_error(exception)
    # Refer: https://github.com/jgorset/facebook-messenger/blob/64fe1f5cef4c1e3fca295b205037f64dfebdbcab/lib/facebook/messenger/error.rb
    return unless exception.to_s.include?('The session has been invalidated') || exception.to_s.include?('Error validating access token')

    channel.authorization_error!
  end
end
