# frozen_string_literal: true

# Motor 2.0 — lo que dice una nota de voz o muestra una imagen que mandó el cliente (en WhatsApp los
# prospectos mandan audios y capturas: el anuncio que vieron, el error de su pantalla). Una sola vez por
# adjunto (caché); nil si no se pudo. Lo usa Motor2::MessageText.
#   audio  → la transcripción de OpenAI (la misma de Dali: Assistant::Transcriber)
#   imagen → AiModels::REVIEW la describe en 1 a 3 líneas y copia el texto que traiga, tal cual
class Motor2::MediaReader < Cases::Ai::BaseService
  CACHE = 'motor2/media/v1'
  MAX_IMAGE_BYTES = 5.megabytes
  IMAGE = <<~TEXT
    Un cliente mandó esta imagen por chat a una empresa. Di en español, en 1 a 3 líneas, qué muestra. Si trae texto
    (un mensaje de error, un anuncio, un precio, un modelo, una pantalla), cópialo tal cual. No supongas lo que no se ve.
  TEXT

  # Lo que pide Assistant::Transcriber (como un archivo subido).
  Upload = Data.define(:tempfile, :content_type, :size)

  def self.read(account, attachment)
    return unless %w[audio image].include?(attachment.file_type.to_s) && attachment.file.attached?

    Rails.cache.fetch("#{CACHE}/#{attachment.id}", expires_in: 30.days, skip_nil: true) do
      new(account: account).call(attachment)
    end
  end

  def call(attachment)
    attachment.file_type.to_s == 'audio' ? audio(attachment) : image(attachment)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::MediaReader] adjunto #{attachment.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  def model = AiModels::REVIEW

  def audio(attachment)
    blob = attachment.file.blob
    blob.open do |file|
      text = Assistant::Transcriber.new(account: @account).call(Upload.new(tempfile: file, content_type: blob.content_type, size: blob.byte_size))
      "[nota de voz] #{text}" if text.present?
    end
  rescue Assistant::Transcriber::TooLarge
    nil
  end

  def image(attachment)
    blob = attachment.file.blob
    return if blob.byte_size > MAX_IMAGE_BYTES

    data = "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
    text = chat(system: IMAGE, user: [{ type: 'text', text: 'La imagen:' }, { type: 'image_url', image_url: { url: data } }],
                temperature: 0, max_tokens: 250)
    "[imagen] #{text.to_s.strip}" if text.present?
  end
end
