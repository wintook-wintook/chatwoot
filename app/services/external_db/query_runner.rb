# frozen_string_literal: true

# @query_databases — ejecuta una ExternalDbQuery de forma segura (solo lectura):
#   - valida los parámetros contra params_schema (requeridos + tipo)
#   - convierte placeholders nombrados (:rfc) en bind params (Firebird) o literales
#     tipados y escapados (SQL Server) — nunca interpolación cruda
#   - trunca a row_limit y mide duración
#
# proyecto@erp_productos — dos tipos de parámetro más (docs/erp_productos_plan.md §3.3):
#   words    texto libre del cliente ("laptop hp"): se parte en hasta WORDS_MAX palabras,
#            cada una solo con letras, números, punto y guion (sin comodines ni comillas),
#            y el SQL las usa como :clave_1, :clave_2, :clave_3 (las que falten, NULL).
#   boolean  "si/sí/true/1/yes" → 1; "no/false/0" → 0 (se bindea como entero).
class ExternalDb::QueryRunner
  Result = Struct.new(:columns, :rows, :row_count, :duration_ms, keyword_init: true)
  ParamError = Class.new(StandardError)

  # `:identifier` evita capturar casts `::tipo` y horas '12:30' (consultas curadas).
  NAMED_PARAM = /(?<![:\w]):([a-zA-Z_]\w*)/
  WORDS_MAX = 3
  WORD_CHARS = /[^\p{L}\p{N}.-]/
  TRUE_WORDS = %w[1 si sí true yes s y].freeze
  FALSE_WORDS = %w[0 no false n].freeze

  def initialize(query, params = {})
    @query = query
    @params = (params || {}).transform_keys(&:to_s)
  end

  def perform
    typed, types = coerce_params!
    adapter = ExternalDb::AdapterFactory.build(@query.external_db_connection)
    sql, binds = bind(@query.sql_template, typed, types, adapter)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rows = Array(adapter.select(sql, binds)).first(@query.row_limit)
    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    Result.new(columns: rows.first&.keys || [], rows: rows, row_count: rows.size, duration_ms: duration)
  ensure
    adapter&.close
  end

  private

  # → [valores_tipados_por_clave, tipos_por_clave]
  def coerce_params!
    typed = {}
    types = {}
    Array(@query.params_schema).each do |spec|
      key, value, type = resolve_param(spec)
      next expand_words(key, value, typed, types) if type == 'words'

      typed[key] = value
      types[key] = type == 'boolean' ? 'integer' : type
    end
    [typed, types]
  end

  def resolve_param(spec)
    key  = (spec['key'] || spec[:key]).to_s
    type = (spec['type'] || spec[:type] || 'string').to_s
    raw  = @params[key]
    return [key, nil, type] if blank_optional?(raw, spec, key)

    [key, coerce(raw, type, key), type]
  end

  # true si el parámetro está vacío y es opcional; lanza si está vacío y es requerido.
  def blank_optional?(raw, spec, key)
    return false unless raw.blank? && raw != false
    raise ParamError, "falta el parámetro requerido: #{key}" if spec['required'] || spec[:required]

    true
  end

  # "laptop hp" → :texto_1 = LAPTOP, :texto_2 = HP, :texto_3 = NULL (y :texto, la frase limpia).
  def expand_words(key, value, typed, types)
    words = value.to_s.split.map { |w| w.gsub(WORD_CHARS, '') }.reject(&:blank?).first(WORDS_MAX)
    typed[key] = words.join(' ').presence
    types[key] = 'string'
    WORDS_MAX.times do |i|
      typed["#{key}_#{i + 1}"] = words[i]
      types["#{key}_#{i + 1}"] = 'string'
    end
  end

  def coerce_boolean(raw, key)
    word = raw.to_s.strip.downcase
    return 1 if raw == true || TRUE_WORDS.include?(word)
    return 0 if raw == false || FALSE_WORDS.include?(word)

    raise ParamError, "parámetro inválido '#{key}': se esperaba sí o no"
  end

  def coerce(raw, type, key)
    case type
    when 'boolean' then coerce_boolean(raw, key)
    when 'integer' then Integer(raw.to_s)
    when 'number'  then Float(raw.to_s)
    when 'date'    then raw.is_a?(Date) ? raw : Date.parse(raw.to_s)
    else raw.to_s
    end
  rescue ArgumentError, TypeError
    raise ParamError, "parámetro inválido '#{key}': se esperaba #{type}"
  end

  def bind(template, typed, types, adapter)
    return bind_inline(template, typed, types, adapter) if adapter.inline_binds?

    bind_positional(template, typed)
  end

  def bind_inline(template, typed, types, adapter)
    sql = template.gsub(NAMED_PARAM) do
      key = Regexp.last_match(1)
      ensure_known!(key, typed)
      adapter.literal(typed[key], types[key])
    end
    [sql, []]
  end

  # proyecto@erp_productos — un parámetro vacío se escribe como NULL en el SQL en vez de
  # mandarse como "?" vacío: la gem `fb` no puede bindear nil a un CAST(? AS …) (medido:
  # "specified column is not permitted to be null"), y los filtros opcionales de
  # `buscar_productos` son justo "(CAST(? AS …) IS NULL OR …)". Es seguro: NULL es una
  # palabra fija, no un texto que venga del usuario.
  def bind_positional(template, typed)
    binds = []
    sql = template.gsub(NAMED_PARAM) do
      key = Regexp.last_match(1)
      ensure_known!(key, typed)
      next 'NULL' if typed[key].nil?

      binds << typed[key]
      '?'
    end
    [sql, binds]
  end

  def ensure_known!(key, typed)
    return if typed.key?(key)

    raise ParamError, "el SQL usa :#{key} pero no está declarado en params_schema"
  end
end
