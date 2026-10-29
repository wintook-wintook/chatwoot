require 'faraday'
require 'faraday/multipart'

# Cliente de la TikTok Business API para mensajería.
#
# El token SIEMPRE se obtiene de Channel::Tiktok#validated_access_token: aquí se recibe ya
# resuelto, este objeto nunca renueva nada.
class Tiktok::Client
  pattr_initialize [:business_id!, :access_token!]

  def business_account_details
    json = get('business/get/', business_id: business_id, fields: %w[username display_name profile_image].to_s)

    {
      username: json['data']['username'],
      display_name: json['data']['display_name'],
      profile_image: json['data']['profile_image']
    }.with_indifferent_access
  end

  # URL temporal desde la que descargar un adjunto recibido.
  def file_download_url(conversation_id, message_id, media_id, media_type = 'IMAGE')
    json = post('business/message/media/download/',
                business_id: business_id, conversation_id: conversation_id,
                message_id: message_id, media_id: media_id, media_type: media_type)

    json['data']['download_url']
  end

  # TikTok decide POR CONVERSACIÓN si se pueden mandar imágenes. Preguntarlo antes evita
  # un envío que la API rechazaría entero.
  def image_send_capable?(conversation_id, conversation_type: 'SINGLE')
    json = get('business/message/capabilities/get/',
               business_id: business_id, conversation_id: conversation_id,
               conversation_type: conversation_type, capability_types: ['IMAGE_SEND'].to_json)

    capabilities = json.dig('data', 'capability_infos') || []
    capabilities.find { |c| c['capability_type'] == 'IMAGE_SEND' }&.[]('capability_result') == true
  end

  def send_text_message(conversation_id, text, referenced_message_id: nil)
    body = { message_type: 'TEXT', text: { body: text } }
    send_message(conversation_id, body, referenced_message_id: referenced_message_id)
  end

  # Solo imágenes: es lo único que admite la API a día de hoy. Hay que subir el fichero
  # primero y mandar el media_id resultante.
  def send_media_message(conversation_id, attachment)
    media_id = upload_media(attachment.file.blob)
    send_message(conversation_id, { message_type: 'IMAGE', image: { media_id: media_id } })
  end

  private

  # @see https://business-api.tiktok.com/portal/docs?id=1832184403754242
  def send_message(conversation_id, payload, referenced_message_id: nil)
    body = { business_id: business_id, recipient_type: 'CONVERSATION', recipient: conversation_id }.merge(payload)
    body[:referenced_message_info] = { referenced_message_id: referenced_message_id } if referenced_message_id.present?

    json = post('business/message/send/', **body)
    json['data']['message']['message_id']
  end

  def upload_media(blob, media_type = 'IMAGE')
    blob.open do |temp_file|
      temp_file.rewind
      payload = {
        business_id: business_id,
        media_type: media_type,
        file: Faraday::Multipart::FilePart.new(temp_file, blob.content_type || 'application/octet-stream', blob.filename.to_s)
      }

      response = multipart_connection.post("#{api_base_url}/business/message/media/upload/", payload) do |request|
        request.headers['Access-Token'] = access_token
      end

      process_json_response(response, 'Failed to upload TikTok media')['data']['media_id']
    end
  end

  def multipart_connection
    @multipart_connection ||= Faraday.new { |f| f.request :multipart }
  end

  def get(path, **query)
    response = HTTParty.get("#{api_base_url}/#{path}", query: query, headers: { 'Access-Token' => access_token, 'Accept' => 'application/json' })
    process_json_response(response, "Failed to call TikTok #{path}")
  end

  def post(path, **body)
    response = HTTParty.post("#{api_base_url}/#{path}", body: body.to_json,
                                                        headers: { 'Access-Token' => access_token, 'Content-Type' => 'application/json',
                                                                   'Accept' => 'application/json' })
    process_json_response(response, "Failed to call TikTok #{path}")
  end

  # TikTok responde HTTP 200 con `code != 0` cuando algo falla: mirar solo el estado deja
  # pasar errores como si fueran éxitos.
  def process_json_response(response, error_prefix)
    unless response.success?
      Rails.logger.error "#{error_prefix}. Status: #{response_status(response)}, Body: #{response.body}"
      raise Tiktok::AuthClient::TiktokApiError, "#{response_status(response)}: #{response.body}"
    end

    json = JSON.parse(response.body)
    raise Tiktok::AuthClient::TiktokApiError, "#{json['code']}: #{json['message']}" if json['code'] != 0

    json
  end

  # HTTParty expone `code`; Faraday, `status`.
  def response_status(response)
    response.respond_to?(:code) ? response.code : response.status
  end

  def api_base_url
    "https://business-api.tiktok.com/open_api/#{GlobalConfigService.load('TIKTOK_API_VERSION', 'v1.3')}"
  end
end
