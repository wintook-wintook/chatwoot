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
    return @errors << 'Body: el cuerpo es obligatorio' if body.blank?

    @errors << "Body: excede #{MAX_BODY} caracteres (#{body.length})" if body.length > MAX_BODY
    check_contiguous(variables(body), 'Body')
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
    return @errors << 'Cabecera de texto: falta el contenido' if text.blank?

    @errors << "Cabecera: excede #{MAX_HEADER_TEXT} caracteres (#{text.length})" if text.length > MAX_HEADER_TEXT

    vars = variables(text)
    @errors << 'Cabecera: máximo 1 variable' if vars.uniq.size > 1
    @errors << 'Cabecera: la variable debe ser exactamente {{1}}' if vars.any? && vars.uniq != [1]
  end

  def validate_header_media
    return if @t.header_media_url.to_s.present? || @t.header_handle.to_s.present?

    @errors << 'Cabecera multimedia: falta el archivo (URL o handle)'
  end

  # ---- footer ----------------------------------------------------------------
  def validate_footer
    footer = @t.footer_text.to_s
    return if footer.blank?

    @errors << "Pie: excede #{MAX_FOOTER} caracteres (#{footer.length})" if footer.length > MAX_FOOTER
    @errors << 'Pie: no puede contener variables' if variables(footer).any?
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
    @errors << "Botones: máximo #{MAX_URL_BUTTONS} de tipo URL" if counts.fetch('URL', 0) > MAX_URL_BUTTONS
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
    return @errors << "Botón ##{pos} (URL) sin url" if url.blank?

    # URL con variable exige example para la revisión de Meta.
    return unless variables(url).any?

    @errors << "Botón ##{pos} (URL) con {{1}} exige example" if Array(btn_field(btn, 'example')).all? { |v| v.to_s.blank? }
  end

  def validate_phone_button(btn, pos)
    @errors << "Botón ##{pos} (teléfono) sin phone_number" if btn_field(btn, 'phone_number').to_s.blank?
  end

  def validate_copy_code_button(btn, pos)
    @errors << "Botón ##{pos} (código) exige example" if Array(btn_field(btn, 'example')).all? { |v| v.to_s.blank? }
  end

  # ---- samples ---------------------------------------------------------------
  def validate_samples
    validate_body_samples
    validate_header_samples
  end

  def validate_body_samples
    expected = variables(@t.body_text).uniq.size
    given = Array(samples['body'])
    if given.size != expected
      @errors << "Ejemplos: se requieren #{expected} valor(es) de body (hay #{given.size})"
    elsif given.any? { |v| v.to_s.strip.empty? }
      @errors << 'Ejemplos: hay valores de body vacíos'
    end
  end

  def validate_header_samples
    return unless @t.header_type.to_s == 'text' && variables(@t.header_content).any?

    given = Array(samples['header'])
    @errors << 'Ejemplos: falta el valor de la cabecera' if given.size != 1 || given.first.to_s.strip.empty?
  end

  # ---- helpers ---------------------------------------------------------------
  def variables(text)
    text.to_s.scan(VAR_REGEX).flatten.map(&:to_i)
  end

  # Chequea que las variables sean contiguas empezando en 1 ({{1}} {{3}} → inválido).
  def check_contiguous(nums, field)
    return if nums.empty?

    sorted = nums.uniq.sort
    return @errors << "#{field}: la primera variable debe ser {{1}}" if sorted.first != 1

    missing = (1..sorted.max).to_a - sorted
    @errors << "#{field}: falta la variable {{#{missing.first}}}" if missing.any?
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
