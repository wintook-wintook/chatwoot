# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — DICTARLE AL ASISTENTE
# ================================================================================
# Pasa a texto lo que la persona dicta en el chat del Asistente. El texto vuelve al
# cuadro de mensaje SIN enviarse: se revisa antes, igual que si se hubiera escrito.
#
# Con la integración de OpenAI de la cuenta, la misma que usa todo el motor. Se eligió
# grabar y transcribir antes que el dictado del navegador (Web Speech API): ese solo
# funciona en Chrome/Edge y manda el audio a Google; este funciona en cualquier
# navegador que pueda grabar, que ya es requisito del grabador nativo de Chatwoot.
#
# `prompt` le da vocabulario al transcriptor: sin él, "@ruta" sale "a ruta", y los
# nombres de la cuenta (etiquetas, tipos de caso) salen con cualquier ortografía.
# ================================================================================

class ContactTrackings::Assistant::Transcriber
  API_URL = 'https://api.openai.com/v1/audio/transcriptions'
  MODEL = 'whisper-1'
  # El tope de OpenAI es 25 MB. 20 deja margen; en ogg/opus son horas de voz.
  MAX_BYTES = 20.megabytes
  READ_TIMEOUT = 120
  VOCABULARY = %w[Entrenamiento ruta rutas rama ramas etiqueta escalamiento deriva agendar cita
                  @ruta @crear_ticket @agendar_calendar Kontrolya CFDI WhatsApp].freeze

  def initialize(account, file:)
    @account = account
    @file = file
  end

  # { text: } o { error: :no_api_key | :no_audio | :too_large | :unavailable }
  def call
    return { error: :no_audio } unless audio?
    return { error: :too_large } if @file.size > MAX_BYTES
    return { error: :no_api_key } if api_key.blank?

    texto = transcribe
    texto.nil? ? { error: :unavailable } : { text: texto.strip }
  end

  private

  def audio?
    @file.respond_to?(:read) && @file.size.to_i.positive? && @file.content_type.to_s.start_with?('audio/', 'video/webm')
  end

  def transcribe
    request = Net::HTTP::Post.new(URI(API_URL))
    request['Authorization'] = "Bearer #{api_key}"
    request.set_form(form, 'multipart/form-data')

    response = http.request(request)
    return failure("HTTP #{response.code}: #{response.body.to_s[0, 300]}") unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['text'].to_s
  rescue StandardError => e
    failure(e.message)
  end

  def form
    [['file', @file.tempfile || @file, { filename: @file.original_filename.presence || 'dictado.ogg',
                                         content_type: @file.content_type }],
     ['model', MODEL],
     ['language', ContactTrackings::Assistant::Language.resolve.to_s],
     ['prompt', vocabulary]]
  end

  def vocabulary
    (VOCABULARY + @account.labels.pluck(:title).map { |t| "##{t}" } +
      CaseType.where(account_id: @account.id).pluck(:name)).uniq.join(', ')
  end

  def http
    require 'net/http'
    uri = URI(API_URL)
    Net::HTTP.new(uri.host, uri.port).tap do |h|
      h.use_ssl = true
      h.read_timeout = READ_TIMEOUT
    end
  end

  def api_key
    @api_key ||= @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
  end

  def failure(detail)
    Rails.logger.error("[Asistente] no se pudo transcribir: #{detail}")
    nil
  end
end
