# Cotizaciones › Formatos — el PDF de la cotización con su formato, con wkhtmltopdf (las imágenes van dentro del
# HTML). Se descarga desde la liga del cliente y se adjunta al mandar la cotización (Quotes::Delivery).
#
#   Quotes::Pdf.available?          → si el servidor tiene wkhtmltopdf
#   Quotes::Pdf.new(quote).render   → los bytes del PDF (lanza Quotes::Pdf::Error si falla)
#   Quotes::Pdf.new(quote).blob     → ActiveStorage::Blob listo para adjuntar a un mensaje
class Quotes::Pdf
  Error = Class.new(StandardError)
  BINARY = ENV.fetch('WKHTMLTOPDF_PATH', '/usr/bin/wkhtmltopdf')
  TIMEOUT = 40

  def self.available? = File.executable?(BINARY)

  def initialize(quote, format: nil)
    @quote = quote
    @format = format
  end

  def filename = "#{@quote.folio}.pdf"

  def render
    raise Error, 'wkhtmltopdf no está instalado' unless self.class.available?

    out, err, status = Timeout.timeout(TIMEOUT) { Open3.capture3(*command, stdin_data: html, binmode: true) }
    raise Error, "wkhtmltopdf: #{err.to_s.lines.last(3).join.strip}" unless status.success? && out.start_with?('%PDF')

    out
  rescue Timeout::Error
    raise Error, 'wkhtmltopdf tardó demasiado'
  end

  def blob
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(render), filename: filename, content_type: 'application/pdf')
  end

  def html
    doc = Quotes::Document.new(@quote, format: @format, inline_images: true)
    I18n.with_locale(@quote.account.locale.presence || I18n.default_locale) do
      ApplicationController.render(template: 'quotes/standalone', layout: false, locals: { doc: doc, pdf: true })
    end
  end

  private

  def command
    paper = @format&.config&.dig('brand', 'paper') || Quotes::Document.new(@quote).brand['paper']
    [BINARY, '--quiet', '--encoding', 'utf-8', '--page-size', paper == 'a4' ? 'A4' : 'Letter',
     '--margin-top', '14mm', '--margin-bottom', '16mm', '--margin-left', '14mm', '--margin-right', '14mm',
     '--footer-font-size', '8', '--footer-right', '[page] / [topage]', '--print-media-type', '-', '-']
  end
end
