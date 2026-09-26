# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — EL TEXTO DE UN ADJUNTO (pieza 7, 26/09/2026)
# ================================================================================
# En el corpus de SSUSA el detalle viene adjunto: la requisición en PDF (ej. 23, OCI747255),
# la tabla de datos en Excel (ej. 8), fichas técnicas. Antes el motor solo veía
# «[archivo adjunto: X.pdf]». Ahora ve el texto:
#
#   .xlsx          filas de cada hoja «A | B | C» (ZipReader + Nokogiri, sin IA)
#   .docx          párrafos y tablas (ZipReader + Nokogiri, sin IA)
#   .csv / .txt    tal cual
#   .pdf           lo transcribe la IA (OpenAI acepta el PDF como archivo): sin gema de PDF en
#                  el proyecto, sacar el texto a mano de un PDF no es confiable
#
# Una sola vez por adjunto (caché). nil = no se pudo o no es un formato de texto.
# ================================================================================

class ContactTrackings::AttachmentText
  MAX_CHARS = 6000
  MAX_ROWS = 200
  MAX_PDF_BYTES = 8 * 1024 * 1024
  CACHE_VERSION = 'v1'

  def self.for(attachment)
    return nil unless attachment&.file_type.to_s == 'file' && attachment.file.attached?

    Rails.cache.fetch("attachment_text/#{CACHE_VERSION}/#{attachment.id}", expires_in: 30.days, skip_nil: true) do
      new(attachment).extract
    end
  rescue StandardError => e
    Rails.logger.warn "[AttachmentText] ⚠️ adjunto #{attachment&.id}: #{e.message}"
    nil
  end

  # El mensaje con el texto de sus adjuntos, para quien lo lea (el motor, el extractor de servicios).
  def self.message_text(message)
    partes = [message.content.to_s.strip.presence]
    message.attachments.each do |adjunto|
      texto = self.for(adjunto)
      partes << "[archivo adjunto: #{adjunto.file.filename}]\n#{texto}" if texto.present?
    end
    partes.compact.join("\n\n")
  end

  def initialize(attachment)
    @attachment = attachment
    @blob = attachment.file.blob
  end

  def extract
    texto = case extension
            when 'xlsx' then xlsx
            when 'docx' then docx
            when 'csv', 'txt' then @blob.download.force_encoding('UTF-8').scrub
            when 'pdf' then pdf
            end
    texto.to_s.strip.truncate(MAX_CHARS).presence
  end

  private

  def extension
    ext = @blob.filename.extension.to_s.downcase
    return 'pdf' if ext.blank? && @blob.content_type == 'application/pdf'

    ext
  end

  # ── Excel ────────────────────────────────────────────────────────────────────
  def xlsx
    partes = ContactTrackings::ZipReader.new(@blob.download).entries(only: ->(n) { n.start_with?('xl/') && n.end_with?('.xml') })
    compartidas = shared_strings(partes['xl/sharedStrings.xml'])
    nombres = sheet_names(partes['xl/workbook.xml'])
    worksheets(partes).each_with_index.filter_map do |hoja, i|
      filas = sheet_rows(hoja, compartidas)
      "Hoja: #{nombres[i] || "Hoja #{i + 1}"}\n#{filas.join("\n")}" if filas.any?
    end.join("\n\n")
  end

  # Las hojas en su orden (sheet1, sheet2…).
  def worksheets(partes)
    partes.keys.grep(%r{\Axl/worksheets/sheet\d+\.xml\z}).sort_by { |n| n[/\d+/].to_i }.map { |n| partes[n] }
  end

  def shared_strings(xml)
    return [] if xml.blank?

    Nokogiri::XML(xml).remove_namespaces!.xpath('//si').map { |si| si.xpath('.//t').map(&:text).join }
  end

  def sheet_names(xml)
    return [] if xml.blank?

    Nokogiri::XML(xml).remove_namespaces!.xpath('//sheet').pluck('name')
  end

  def sheet_rows(xml, compartidas)
    Nokogiri::XML(xml).remove_namespaces!.xpath('//row').first(MAX_ROWS).filter_map do |fila|
      celdas = fila.xpath('c').map { |c| cell_value(c, compartidas) }
      celdas.join(' | ') if celdas.any?(&:present?)
    end
  end

  def cell_value(celda, compartidas)
    case celda['t']
    when 's' then compartidas[celda.at_xpath('v')&.text.to_i].to_s
    when 'inlineStr' then celda.xpath('.//t').map(&:text).join
    else celda.at_xpath('v')&.text.to_s
    end
  end

  # ── Word ─────────────────────────────────────────────────────────────────────
  def docx
    xml = ContactTrackings::ZipReader.new(@blob.download).entries(only: ->(n) { n == 'word/document.xml' })['word/document.xml']
    return nil if xml.blank?

    cuerpo = Nokogiri::XML(xml).remove_namespaces!.at_xpath('//body')
    cuerpo.element_children.filter_map { |nodo| docx_block(nodo) }.join("\n")
  end

  def docx_block(nodo)
    if nodo.name == 'tbl'
      nodo.xpath('.//tr').map { |tr| tr.xpath('tc').map { |tc| tc.xpath('.//t').map(&:text).join }.join(' | ') }.join("\n")
    else
      nodo.xpath('.//t').map(&:text).join.presence
    end
  end

  # ── PDF ──────────────────────────────────────────────────────────────────────
  def pdf
    return nil if @blob.byte_size > MAX_PDF_BYTES

    api_key = @attachment.account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
    return nil if api_key.blank?

    respuesta = HTTParty.post('https://api.openai.com/v1/chat/completions',
                              headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
                              body: pdf_request.to_json, timeout: 90)
    raise "OpenAI #{respuesta.code}" unless respuesta.success?

    respuesta.parsed_response.dig('choices', 0, 'message', 'content')
  end

  def pdf_request
    datos = "data:application/pdf;base64,#{Base64.strict_encode64(@blob.download)}"
    { model: 'gpt-4o-mini', temperature: 0, max_tokens: 3000,
      messages: [{ role: 'user', content: [
        { type: 'text', text: 'Transcribe TODO el texto de este documento, tal cual, sin resumir ni comentar. ' \
                              'Las tablas, una fila por línea con las celdas separadas por « | ».' },
        { type: 'file', file: { filename: @blob.filename.to_s, file_data: datos } }
      ] }] }
  end
end
