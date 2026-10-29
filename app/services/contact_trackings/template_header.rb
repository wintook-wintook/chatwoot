# frozen_string_literal: true

# ================================================================================
# feat/plantillas_whatsapp_mejoras F5 — EL ARCHIVO DEL ENCABEZADO EN SEGUIMIENTOS Y CAMPAÑAS
# ================================================================================
# Plan: docs/plantillas_whatsapp_mejoras_plan.md §4 (F5). Un seguimiento (o una campaña,
# que envía por el mismo ContactTrackingJob) manda solo los parámetros del cuerpo: con una
# plantilla de imagen, video o documento Meta lo rechazaba. Aquí se decide qué encabezado
# lleva:
#
#   nil                 la plantilla no lleva archivo: se envía como siempre
#   Result(media:)      lleva archivo y está guardado en la plantilla (el subido en la
#                       pantalla, F6, o el header_media_url de su fila): va como
#                       encabezado, igual que en la conversación (F1)
#   Result(error:)      lleva archivo y no se puede mandar (no hay archivo guardado, o la
#                       bandeja no es WhatsApp Cloud): NO se envía y queda el motivo
#
# El error se registra con el código propio MISSING_CODE, que ErrorClassifier cuenta como
# `config`: se pausa el seguimiento o la campaña con el motivo (no es culpa del contacto).
# ================================================================================

module ContactTrackings::TemplateHeader
  MEDIA_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze
  MISSING_CODE = 'template_media_missing'
  NAMES = { 'image' => 'una imagen', 'video' => 'un video', 'document' => 'un documento' }.freeze

  Result = Struct.new(:media, :error, keyword_init: true) do
    # Los components para Meta: encabezado con el archivo + el cuerpo de siempre.
    def components(body_parameters)
      componentes = [{ type: 'header', parameters: [media_parameter] }]
      componentes << { type: 'body', parameters: body_parameters } if Array(body_parameters).any?
      componentes
    end

    # Para template_params.processed_params del mensaje: así la burbuja muestra el archivo (F3).
    def processed_header
      { 'media_url' => media[:url], 'media_type' => media[:type], 'media_name' => media[:name] }.compact
    end

    # El error en el formato que guardan las entregas (TrackingDelivery.parse_error).
    def external_error
      { error: { code: MISSING_CODE, message: error } }.to_json
    end

    private

    def media_parameter
      Whatsapp::PopulateTemplateParametersService.new.build_media_parameter(media[:url], media[:type], media[:name])
    end
  end

  module_function

  def for(channel, template_name, language)
    tipo = media_type(channel, template_name)
    return if tipo.nil?

    unless channel.provider == 'whatsapp_cloud'
      return Result.new(error: "La plantilla «#{template_name}» lleva #{NAMES[tipo]} en el encabezado y esta bandeja no " \
                               'puede mandarlo (solo WhatsApp Cloud).')
    end

    fila = stored_template(channel, template_name, language)
    return Result.new(media: { type: tipo, url: fila.header_media_link, name: file_name(fila, tipo) }) if fila

    Result.new(error: "La plantilla «#{template_name}» lleva #{NAMES[tipo]} en el encabezado y no tiene archivo guardado: " \
                      'súbelo en la pantalla de plantillas.')
  end

  # 'image' | 'video' | 'document', o nil si la plantilla no lleva archivo.
  def media_type(channel, template_name)
    plantilla = Array(channel.try(:message_templates)).find { |t| t['name'] == template_name }
    header = Array(plantilla && plantilla['components']).find { |c| c['type'] == 'HEADER' }
    formato = header && header['format'].to_s.upcase
    MEDIA_FORMATS.include?(formato) ? formato.downcase : nil
  end

  # La fila con archivo guardado: el subido en la pantalla (F6, liga fresca) o la liga pegada
  # a mano. La del mismo idioma, o la que haya.
  def stored_template(channel, template_name, language)
    filas = channel.whatsapp_templates.where(name: template_name).to_a.select { |t| t.header_media_link.present? }
    filas.find { |t| t.language == language } || filas.first
  end

  # Solo el documento lleva nombre: el del archivo subido o, si se pegó una liga, el de la liga
  # (la liga de un archivo subido es una clave firmada, no un nombre).
  def file_name(fila, tipo)
    return unless tipo == 'document'
    return fila.header_sample.filename.to_s if fila.header_sample.attached?

    File.basename(URI.parse(fila.header_media_url.to_s).path).presence
  rescue URI::InvalidURIError
    nil
  end
end
