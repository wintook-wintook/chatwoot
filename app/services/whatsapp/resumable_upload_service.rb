# frozen_string_literal: true

# @waba_templates
# Resumable Upload de Meta para la cabecera de imagen de una plantilla. Meta NO acepta una
# URL plana al crear: exige `example.header_handle`. Flujo de 2 pasos:
#   1. POST /{APP_ID}/uploads (crea la sesión)
#   2. POST /{upload_session_id} con los bytes → devuelve el handle `h`
#
# App ID: META_APP_ID si existe, si no FB_APP_ID (config global de Chatwoot).
# Alcance v1: SOLO imagen (JPEG/PNG, ≤5 MB).
# TODO(waba): mismo flujo para video/document.
class Whatsapp::ResumableUploadService
  GRAPH_VERSION = ENV.fetch('WHATSAPP_GRAPH_VERSION', 'v20.0')
  MAX_BYTES = 5 * 1024 * 1024
  ALLOWED_TYPES = %w[image/jpeg image/png].freeze

  Result = Struct.new(:success, :handle, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(channel:, media_url:)
    @channel = channel
    @media_url = media_url
  end

  def perform
    app_id = resolve_app_id
    return failure('Falta META_APP_ID / FB_APP_ID para subir la imagen de cabecera') if app_id.blank?

    file = download_media
    return file if file.is_a?(Result) # error de descarga/validación

    session_id = create_upload_session(app_id, file)
    return failure('Meta no devolvió sesión de subida') if session_id.blank?

    handle = upload_bytes(session_id, file[:bytes])
    return failure('Meta no devolvió el handle de la imagen') if handle.blank?

    Result.new(success: true, handle: handle)
  rescue StandardError => e
    Rails.logger.error "[waba_templates] resumable upload falló: #{e.message}"
    failure(e.message)
  end

  private

  def resolve_app_id
    ENV['META_APP_ID'].presence || GlobalConfigService.load('FB_APP_ID', nil)
  end

  # Descarga los bytes de la URL y valida tipo + tamaño.
  def download_media
    tempfile = Down.download(@media_url, max_size: MAX_BYTES)
    content_type = tempfile.content_type
    return failure("Tipo no permitido (#{content_type}); solo JPEG/PNG") unless ALLOWED_TYPES.include?(content_type)

    { bytes: tempfile.read, content_type: content_type, length: tempfile.size }
  rescue Down::TooLarge
    failure("La imagen supera #{MAX_BYTES / (1024 * 1024)} MB")
  rescue Down::Error => e
    failure("No se pudo descargar la imagen: #{e.message}")
  end

  # Paso 1: crea la sesión de subida. Devuelve el id "upload:...".
  def create_upload_session(app_id, file)
    response = HTTParty.post(
      "#{graph_base}/#{app_id}/uploads",
      query: { file_length: file[:length], file_type: file[:content_type], access_token: access_token }
    )
    response.success? ? response.parsed_response['id'] : nil
  end

  # Paso 2: sube los bytes. Devuelve el handle `h`.
  def upload_bytes(session_id, bytes)
    response = HTTParty.post(
      "#{graph_base}/#{session_id}",
      headers: { 'Authorization' => "OAuth #{access_token}", 'file_offset' => '0' },
      body: bytes
    )
    response.success? ? response.parsed_response['h'] : nil
  end

  def graph_base
    base = @channel.provider_config['url'].presence || ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/#{GRAPH_VERSION}"
  end

  def access_token
    @channel.provider_config['api_key']
  end

  def failure(message)
    Result.new(success: false, error: message)
  end
end
