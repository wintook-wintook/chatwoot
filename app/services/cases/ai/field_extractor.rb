# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Extractor de campos personalizados por tipo de caso (intake IA)
# ================================================================================
# Servicio: Cases::Ai::FieldExtractor
#
# Dado un CaseType y la transcripción de la conversación, extrae de ESTA los
# valores de los CAMPOS PARTICULARES de ese tipo (case_type_fields) y detecta
# cuáles OBLIGATORIOS siguen faltando, para que el bot los pregunte.
#
# Devuelve:
#   { 'values'           => { key => valor_saneado },   # solo los realmente presentes
#     'missing_required' => [ CaseTypeField, ... ] }     # required sin valor capturado
#
# Los valores se persisten luego en case_tickets.custom_attributes[key]
# (patrón de CaseTypeField). Tolerante a fallos: ante cualquier error devuelve
# vacío y NO rompe el intake.
# ================================================================================

class Cases::Ai::FieldExtractor < Cases::Ai::BaseService
  def extract(conversation_text:, case_type:)
    fields = ordered_fields(case_type)
    return empty if fields.blank?

    values  = extract_values(conversation_text, fields)
    missing = fields.select { |field| field.required && blank_value?(values[field.key]) }

    { 'values' => values.reject { |_k, v| blank_value?(v) }, 'missing_required' => missing }
  rescue StandardError => e
    Rails.logger.error("[Cases::Ai::FieldExtractor] #{e.message}")
    empty
  end

  private

  def ordered_fields(case_type)
    return [] if case_type.nil?

    case_type.case_type_fields.ordered.to_a
  end

  def empty
    { 'values' => {}, 'missing_required' => [] }
  end

  # Llama al LLM y castea la respuesta a { key => valor_o_nil } para todos los campos.
  def extract_values(conversation_text, fields)
    raw = chat(
      system: system_prompt,
      user: user_prompt(conversation_text, fields),
      json: true,
      max_tokens: 500
    )
    sanitize_values(raw.is_a?(Hash) ? raw['values'] : nil, fields)
  end

  def system_prompt
    <<~PROMPT.strip
      Extraes de una conversación los valores de los campos de un formulario de soporte.
      Responde EXCLUSIVAMENTE con un objeto JSON: { "values": { "clave": valor } }.
      Reglas:
        - Usa SOLO información presente en la conversación. Si un dato NO aparece, usa null.
        - No inventes ni supongas valores.
        - Para campos tipo "list", el valor debe ser EXACTAMENTE una de las opciones dadas.
        - Para "date" usa formato YYYY-MM-DD. Para "number" solo el número. Para "checkbox" true/false.
        - Para "text" un texto breve.
        - Un mismo dato (medida, cantidad, unidad) pertenece a UN SOLO campo: si ya forma parte de
          la descripción de otro campo (ej. "500 hojas de 10mm" — el 10mm es el espesor del
          material, no un dato aparte), NO lo repitas como valor de un campo distinto salvo que el
          cliente lo haya dado explícitamente PARA ese otro campo.
        - Si el cliente da dos datos de ubicación en la misma frase con un patrón tipo "de A para B"
          o "de A a B", asigná A al campo de origen/recogida y B al campo de destino según la
          etiqueta de cada uno — no los dejes en null ni los mezclés.
      La clave ("clave") de cada valor es el "key" del campo.
    PROMPT
  end

  def user_prompt(conversation_text, fields)
    <<~PROMPT.strip
      CONVERSACIÓN:
      #{conversation_text.presence || '(sin contexto)'}

      CAMPOS A EXTRAER (key · tipo · etiqueta · opciones):
      #{fields.map { |f| field_line(f) }.join("\n")}
    PROMPT
  end

  def field_line(field)
    opts = field.field_list? ? " · opciones: [#{Array(field.options).join(', ')}]" : ''
    "#{field.key} · #{field.field_type} · #{field.label}#{opts}"
  end

  # Devuelve { key => valor_casteado_o_nil } para TODOS los campos del tipo.
  def sanitize_values(raw_values, fields)
    raw = raw_values.is_a?(Hash) ? raw_values : {}
    fields.each_with_object({}) do |field, memo|
      memo[field.key] = cast_value(field, raw[field.key])
    end
  end

  def cast_value(field, value)
    return nil if value.nil? || value.to_s.strip.empty?

    case field.field_type.to_sym
    when :number   then numeric(value)
    when :date     then iso_date(value)
    when :checkbox then ActiveModel::Type::Boolean.new.cast(value)
    when :list     then option_match(field, value)
    else value.to_s.strip.presence
    end
  end

  def numeric(value)
    str = value.to_s.strip
    return nil unless str.match?(/\A-?\d+(\.\d+)?\z/)

    str.include?('.') ? str.to_f : str.to_i
  end

  def iso_date(value)
    Date.iso8601(value.to_s.strip).iso8601
  rescue ArgumentError
    begin
      Date.parse(value.to_s.strip).iso8601
    rescue ArgumentError
      nil
    end
  end

  def option_match(field, value)
    needle = value.to_s.strip
    Array(field.options).find { |opt| opt.to_s.casecmp?(needle) }
  end

  # Un booleano (true/false) SIEMPRE cuenta como valor presente; el resto usa blank?.
  def blank_value?(value)
    return false if [true, false].include?(value)

    value.nil? || (value.respond_to?(:blank?) && value.blank?)
  end
end
