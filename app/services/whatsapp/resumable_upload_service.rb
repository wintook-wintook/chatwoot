# frozen_string_literal: true

# @waba_templates
# Resumable Upload de Meta para el archivo de muestra de la cabecera de una plantilla. Meta
# NO acepta una URL plana al crear: exige `example.header_handle`. Flujo de 2 pasos:
#   1. POST /{APP_ID}/uploads (crea la sesión)
#   2. POST /{upload_session_id} con los bytes → devuelve el handle `h`
#
# App ID: META_APP_ID (variable de entorno o la config del super admin «Meta App ID (WhatsApp
# templates)»), si no FB_APP_ID. Antes la de META_APP_ID solo se leía del entorno: lo que se
# ponía en el super admin se ignoraba.
#
# feat/plantillas_whatsapp_mejoras F0: imagen, video y documento (antes solo imagen; video y
# documento mandaban la liga cruda como handle y Meta las rechazaba). Límites de Meta:
#   imagen JPEG/PNG ≤ 5 MB · video MP4/3GPP ≤ 16 MB · documento PDF ≤ 100 MB
class Whatsapp::ResumableUploadService
  GRAPH_VERSION = ENV.fetch('WHATSAPP_GRAPH_VERSION', 'v20.0')
  MB = 1024 * 1024
  LIMITS = {
    'image' => { types: %w[image/jpeg image/png], max: 5 * MB, label: 'La imagen', allowed: 'JPEG/PNG' },
    'video' => { types: %w[video/mp4 video/3gpp], max: 16 * MB, label: 'El video', allowed: 'MP4/3GPP' },
    'document' => { types: %w[application/pdf], max: 100 * MB, label: 'El documento', allowed: 'PDF' }
  }.freeze
  # Compatibilidad: lo que antes era la única regla (imagen).
  MAX_BYTES = LIMITS['image'][:max]
  ALLOWED_TYPES = LIMITS['image'][:types]

  Result = Struct.new(:success, :handle, :error, keyword_init: true) do
    def success?
      success
    end
  end

  # Lo que tiene mal un archivo subido para el encabezado del tipo dado (nil = sirve). Lo
  # usan la pantalla de plantillas (muestra) y la conversación (archivo para un envío).
  def self.file_error(archivo, header_type)
    limites = LIMITS[header_type.to_s]
    return 'Tipo de encabezado no válido' if limites.nil?
    return 'Falta el archivo' unless archivo.respond_to?(:content_type)
    return "Tipo no permitido (#{archivo.content_type}); solo #{limites[:allowed]}" unless limites[:types].include?(archivo.content_type)

    "#{limites[:label]} supera #{limites[:max] / MB} MB" if archivo.size > limites[:max]
  end

  def initialize(channel:, media_url:, header_type: 'image')
    @channel = channel
    @media_url = media_url
    @limits = LIMITS.fetch(header_type.to_s, LIMITS['image'])
  end

  def perform
    app_id = resolve_app_id
    return failure('Falta META_APP_ID / FB_APP_ID para subir el archivo de cabecera') if app_id.blank?

    file = download_media
    return file if file.is_a?(Result) # error de descarga/validación

    session_id = create_upload_session(app_id, file)
    return failure('Meta no devolvió sesión de subida') if session_id.blank?

    handle = upload_bytes(session_id, file[:bytes])
    return failure('Meta no devolvió el handle del archivo') if handle.blank?

    Result.new(success: true, handle: handle)
  rescue StandardError => e
    Rails.logger.error "[waba_templates] resumable upload falló: #{e.message}"
    failure(e.message)
  end

  private

  def resolve_app_id
    GlobalConfigService.load('META_APP_ID', nil).presence || GlobalConfigService.load('FB_APP_ID', nil)
  end

  # Descarga los bytes de la URL y valida tipo + tamaño.
  def download_media
    tempfile = Down.download(@media_url, max_size: @limits[:max])
    content_type = tempfile.content_type
    return failure("Tipo no permitido (#{content_type}); solo #{@limits[:allowed]}") unless @limits[:types].include?(content_type)

    { bytes: tempfile.read, content_type: content_type, length: tempfile.size }
  rescue Down::TooLarge
    failure("#{@limits[:label]} supera #{@limits[:max] / MB} MB")
  rescue Down::Error => e
    failure("No se pudo descargar el archivo: #{e.message}")
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
