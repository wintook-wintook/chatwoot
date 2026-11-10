# frozen_string_literal: true

# @waba_templates
# Validador PURO de plantillas contra las reglas de Meta. Corre ANTES de cualquier llamada
# a la API. Cada regla acumula un error ESPECÍFICO por campo (no un genérico). Sin efectos
# secundarios ni red → se reusa 1:1 en el cliente (JS) para feedback en vivo.
#
# Entrada: un objeto tipo WhatsappTemplate (duck-typed: name, category, language,
#          header_type, header_content, body_text, footer_text, buttons, sample_values).
# Salida:  Whatsapp::TemplateValidator::Result(errors:) con `valid?`.
class Whatsapp::TemplateValidator
  Result = Struct.new(:errors, keyword_init: true) do
    def valid?
      errors.empty?
    end
  end

  NAME_FORMAT = /\A[a-z0-9_]{1,512}\z/
  VAR_REGEX = /\{\{\s*(\d+)\s*\}\}/

  MAX_BODY = 1024
  MAX_FOOTER = 60
  MAX_HEADER_TEXT = 60
  MAX_BUTTON_TEXT = 25
  MAX_COPY_CODE = 15

  MAX_BUTTONS = 10
  MAX_URL_BUTTONS = 2
  MAX_PHONE_BUTTONS = 1
  MAX_COPY_CODE_BUTTONS = 1

  CTA_TYPES = %w[URL PHONE_NUMBER COPY_CODE].freeze

  def self.call(template)
    new(template).call
  end

  def initialize(template)
    @t = template
    @errors = []
  end

  def call
    validate_name
    validate_category
    validate_variable_format
    validate_body
    validate_header
    validate_footer
    validate_buttons
    validate_samples
    Result.new(errors: @errors)
  end

  private

  # ---- nombre ----------------------------------------------------------------
  def validate_name
    name = @t.name.to_s
    return @errors << 'Nombre: es obligatorio' if name.blank?

    @errors << 'Nombre: solo minúsculas, números y _ (1-512 caracteres)' unless name.match?(NAME_FORMAT)
  end

  # ---- body ------------------------------------------------------------------
  def validate_body
    body = @t.body_text.to_s
    return @errors << 'Mensaje: es obligatorio' if body.blank?

    @errors << "Mensaje: excede #{MAX_BODY} caracteres (#{body.length})" if body.length > MAX_BODY
    @errors.concat(Whatsapp::TemplateVariables.body_errors(body))
  end

  # ---- variables -------------------------------------------------------------
  def validate_variable_format
    header = @t.header_type.to_s == 'text' ? @t.header_content : nil
    @errors.concat(Whatsapp::TemplateVariables.format_errors(header, @t.body_text))
  end

  # ---- categoría ------------------------------------------------------------
  # feat/plantillas_whatsapp_mejoras: las de autenticación (códigos de verificación) tienen
  # un formato fijo de Meta (sin texto libre, botón de código y caducidad) que este
  # formulario no arma: Meta las rechazaba. Se crean y editan en WhatsApp Manager.
  def validate_category
    return unless @t.category.to_s.casecmp?('AUTHENTICATION')

    @errors << 'Categoría: las de autenticación (códigos de verificación) se crean en WhatsApp Manager de Meta'
  end

  # ---- header ----------------------------------------------------------------
  def validate_header
    type = @t.header_type.to_s
    return if type.blank?

    if type == 'text'
      validate_header_text
    else # image | video | document
      validate_header_media
    end
  end

  def validate_header_text
    text = @t.header_content.to_s
    return @errors << 'Encabezado: falta el texto' if text.blank?

    @errors << "Encabezado: excede #{MAX_HEADER_TEXT} caracteres (#{text.length})" if text.length > MAX_HEADER_TEXT

    vars = tokens(text).uniq
    @errors << 'Encabezado: máximo 1 variable' if vars.size > 1
    @errors << 'Encabezado: la variable debe ser exactamente {{1}}' if Whatsapp::TemplateVariables.numbers(text).uniq.then { |n| n.any? && n != [1] }
  end

  def validate_header_media
    return if @t.header_media_url.to_s.present? || @t.header_handle.to_s.present?
    # feat/plantillas_whatsapp_mejoras F6: o el archivo subido desde la pantalla.
    return if @t.respond_to?(:header_sample) && @t.header_sample.attached?

    @errors << 'Encabezado: falta el archivo (súbelo o pega una liga)'
  end

  # ---- footer ----------------------------------------------------------------
  def validate_footer
    footer = @t.footer_text.to_s
    return if footer.blank?

    @errors << "Pie: excede #{MAX_FOOTER} caracteres (#{footer.length})" if footer.length > MAX_FOOTER
    @errors << 'Pie: no puede contener variables' if tokens(footer).any?
  end

  # ---- botones ---------------------------------------------------------------
  def validate_buttons
    buttons = Array(@t.buttons)
    return if buttons.empty?

    @errors << "Botones: máximo #{MAX_BUTTONS} (hay #{buttons.size})" if buttons.size > MAX_BUTTONS
    validate_button_type_limits(buttons)
    validate_quick_reply_grouping(buttons)
    buttons.each_with_index { |btn, i| validate_button(btn, i + 1) }
  end

  def validate_button_type_limits(buttons)
    counts = buttons.group_by { |b| btn_type(b) }.transform_values(&:size)
    @errors << "Botones: máximo #{MAX_URL_BUTTONS} de tipo liga" if counts.fetch('URL', 0) > MAX_URL_BUTTONS
    @errors << "Botones: máximo #{MAX_PHONE_BUTTONS} de tipo teléfono" if counts.fetch('PHONE_NUMBER', 0) > MAX_PHONE_BUTTONS
    @errors << "Botones: máximo #{MAX_COPY_CODE_BUTTONS} de tipo código" if counts.fetch('COPY_CODE', 0) > MAX_COPY_CODE_BUTTONS
  end

  # Los QUICK_REPLY deben ir agrupados al inicio, sin intercalarse con CTA.
  def validate_quick_reply_grouping(buttons)
    seen_cta = false
    buttons.each do |b|
      if btn_type(b) == 'QUICK_REPLY'
        return @errors << 'Botones: las respuestas rápidas deben ir agrupadas al inicio' if seen_cta
      else
        seen_cta = true
      end
    end
  end

  def validate_button(btn, pos)
    type = btn_type(btn)
    text = btn_field(btn, 'text').to_s

    # COPY_CODE no lleva texto libre; el resto sí y respeta el límite.
    if type != 'COPY_CODE' && text.length > MAX_BUTTON_TEXT
      @errors << "Botón ##{pos}: el texto excede #{MAX_BUTTON_TEXT} caracteres"
    end

    case type
    when 'URL'          then validate_url_button(btn, pos)
    when 'PHONE_NUMBER' then validate_phone_button(btn, pos)
    when 'COPY_CODE'    then validate_copy_code_button(btn, pos)
    when 'QUICK_REPLY'  then nil
    else @errors << "Botón ##{pos}: tipo desconocido (#{type})"
    end
  end

  def validate_url_button(btn, pos)
    url = btn_field(btn, 'url').to_s
    return @errors << "Botón ##{pos} (liga): falta la liga" if url.blank?

    # URL con variable exige example para la revisión de Meta.
    return unless variables(url).any?

    @errors << "Botón ##{pos} (liga): falta el ejemplo de la liga completa" if Array(btn_field(btn, 'example')).all? { |v| v.to_s.blank? }
  end

  def validate_phone_button(btn, pos)
    @errors << "Botón ##{pos} (teléfono): falta el número" if btn_field(btn, 'phone_number').to_s.blank?
  end

  def validate_copy_code_button(btn, pos)
    ejemplo = Array(btn_field(btn, 'example')).first.to_s
    return @errors << "Botón ##{pos} (código): falta el código de ejemplo" if ejemplo.blank?

    @errors << "Botón ##{pos} (código): el ejemplo admite hasta #{MAX_COPY_CODE} caracteres" if ejemplo.length > MAX_COPY_CODE
  end

  # ---- samples ---------------------------------------------------------------
  def validate_samples
    validate_body_samples
    validate_header_samples
  end

  def validate_body_samples
    expected = tokens(@t.body_text).uniq.size
    given = Array(samples['body'])
    if given.size != expected
      @errors << "Ejemplos: se requieren #{expected} valor(es) del mensaje (hay #{given.size})"
    elsif given.any? { |v| v.to_s.strip.empty? }
      @errors << 'Ejemplos: hay ejemplos del mensaje vacíos'
    end
  end

  def validate_header_samples
    return unless @t.header_type.to_s == 'text' && tokens(@t.header_content).any?

    given = Array(samples['header'])
    @errors << 'Ejemplos: falta el ejemplo del encabezado' if given.size != 1 || given.first.to_s.strip.empty?
  end

  # ---- helpers ---------------------------------------------------------------
  def variables(text)
    text.to_s.scan(VAR_REGEX).flatten.map(&:to_i)
  end

  def tokens(text)
    Whatsapp::TemplateVariables.tokens(text)
  end

  def samples
    (@t.sample_values || {}).with_indifferent_access
  end

  def btn_type(btn)
    btn_field(btn, 'type').to_s.upcase
  end

  # Lee una clave del botón tolerando claves string (jsonb) o symbol.
  def btn_field(btn, key)
    return if btn.nil?

    btn[key] || btn[key.to_sym]
  end
end
