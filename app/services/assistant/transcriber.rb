# frozen_string_literal: true

# Asistente (Dali) — lo que el usuario le dicta: la nota de voz (grabada en el navegador,
# webm/ogg/mp4) se pasa a texto con la transcripción de OpenAI de la cuenta. El texto
# vuelve al cuadro para que el usuario lo revise antes de mandarlo.
#
# Uso: Assistant::Transcriber.new(account:).call(upload) → 'agéndame una llamada…' | nil
class Assistant::Transcriber < Cases::Ai::BaseService
  URL = 'https://api.openai.com/v1/audio/transcriptions'
  MODEL = ENV.fetch('ASSISTANT_TRANSCRIBE_MODEL', 'gpt-4o-mini-transcribe')
  MAX_BYTES = 10.megabytes
  TIMEOUT = 40

  class TooLarge < StandardError; end

  def call(upload)
    raise TooLarge if upload.size > MAX_BYTES
    return if api_key.blank?

    response = http.request(request(upload))
    return JSON.parse(response.body)['text'].to_s.strip.presence if response.is_a?(Net::HTTPSuccess)

    Rails.logger.error("[Assistant] transcripción HTTP #{response.code}: #{response.body.to_s[0, 300]}")
    nil
  rescue TooLarge
    raise
  rescue StandardError => e
    Rails.logger.error("[Assistant] transcripción: #{e.message}")
    nil
  end

  private

  def http
    require 'net/http'
    uri = URI(URL)
    Net::HTTP.new(uri.host, uri.port).tap do |h|
      h.use_ssl = true
      h.read_timeout = TIMEOUT
    end
  end

  def request(upload)
    form = [['model', MODEL], ['file', upload.tempfile, { filename: filename(upload), content_type: upload.content_type }]]
    form << %w[language es] if @account.locale.to_s.start_with?('es')
    Net::HTTP::Post.new(URI(URL)).tap do |req|
      req['Authorization'] = "Bearer #{api_key}"
      req.set_form(form, 'multipart/form-data')
    end
  end

  # OpenAI reconoce el formato por la extensión.
  def filename(upload)
    ext = upload.content_type.to_s[%r{audio/(\w+)}, 1].presence || 'webm'
    ext = 'm4a' if ext == 'mp4'
    "dictado.#{ext}"
  end
end
