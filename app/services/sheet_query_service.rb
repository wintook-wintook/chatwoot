# @knowledge_sources — Base de Conocimiento / Google Sheets (modo Datos)
#
# Responde preguntas analíticas sobre una hoja (suma, promedio, conteo, filtro)
# SIN usar embeddings: el LLM solo TRADUCE la pregunta a una consulta estructurada
# { op, column, filters } y Ruby la EJECUTA de forma determinista sobre
# google_sheet_rows. Así no se alucinan números.
class SheetQueryService
  OPS = %w[sum avg min max count filter list].freeze
  MAX_LIST = 20

  def initialize(source, question, account)
    @source   = source
    @question = question.to_s.strip
    @account  = account
  end

  # Devuelve un string con la respuesta, o nil si no se pudo resolver.
  def perform
    rows = @source.google_sheet_rows.order(:row_index).pluck(:data)
    return nil if rows.empty?

    headers = rows.first.keys
    spec = translate_to_spec(headers, rows.first(3), categorical_values(rows, headers))
    return nil unless spec

    execute(spec, rows, headers)
  rescue StandardError => e
    Rails.logger.error "[SheetQueryService] #{e.message}"
    nil
  end

  private

  # Valores distintos de columnas categóricas (pocas opciones), para que el LLM
  # pueda mapear palabras sueltas ("vencidas", "de México") al filtro column=value
  # correcto en lugar de inventar condiciones (p. ej. una fecha).
  MAX_DISTINCT = 15

  def categorical_values(rows, headers)
    headers.each_with_object({}) do |col, acc|
      values = rows.filter_map { |r| r[col].to_s.strip.presence }.uniq
      # Columnas con pocos valores distintos y no numéricas → son categóricas.
      next if values.size > MAX_DISTINCT
      next if values.all? { |v| Float(v.delete(','), exception: false) }

      acc[col] = values
    end
  end

  # --- 1) LLM: pregunta → spec estructurada -----------------------------------
  def translate_to_spec(headers, sample, categories = {})
    system = <<~SYS.strip
      Traduces preguntas en español sobre una tabla a una consulta JSON. Devuelve SOLO JSON válido,
      sin texto extra. Esquema:
      { "op": "sum|avg|min|max|count|filter|list", "column": "<encabezado o null>",
        "filters": [ { "column": "<encabezado>", "operator": "=|!=|>|<|>=|<=|contains", "value": "<texto>" } ] }
      Reglas: usa exactamente los encabezados dados. Para "cuántos" usa count. Para "cuáles/lista" usa list.
      Para sumar/promediar/máximo/mínimo usa la columna numérica correspondiente. Si no hay filtros, "filters": [].
      Si la pregunta menciona (aunque sea con otra forma gramatical) uno de los "Valores posibles" listados,
      filtra por esa columna con operator "=" y ese valor exacto, NO inventes condiciones de fecha ni rangos.
    SYS
    categories_block = categories.map { |col, vals| "#{col} = [#{vals.join(', ')}]" }.join('; ')
    user = <<~USR.strip
      Encabezados: #{headers.join(', ')}
      Valores posibles: #{categories_block.presence || '(ninguno categórico)'}
      Primeras filas: #{sample.to_json}
      Pregunta: "#{@question}"
    USR

    raw = openai_chat([{ role: 'system', content: system }, { role: 'user', content: user }], json: true)
    return nil if raw.blank?

    spec = JSON.parse(raw)
    return nil unless OPS.include?(spec['op'])

    spec
  rescue JSON::ParserError
    nil
  end

  # --- 2) Ruby: ejecuta la spec de forma determinista -------------------------
  def execute(spec, rows, headers)
    filtered = apply_filters(rows, spec['filters'], headers)
    col = resolve_header(spec['column'], headers)

    case spec['op']
    when 'count'
      "#{filtered.size}"
    when 'sum', 'avg', 'min', 'max'
      aggregate(spec['op'], filtered, col)
    when 'filter', 'list'
      list_rows(filtered)
    end
  end

  def apply_filters(rows, filters, headers)
    return rows if filters.blank?

    rows.select do |row|
      filters.all? do |f|
        col = resolve_header(f['column'], headers)
        next true if col.nil?

        compare(row[col].to_s, f['operator'], f['value'].to_s)
      end
    end
  end

  def compare(actual, operator, expected)
    a_num = Float(actual, exception: false)
    e_num = Float(expected, exception: false)
    if a_num && e_num
      case operator
      when '>'  then a_num > e_num
      when '<'  then a_num < e_num
      when '>=' then a_num >= e_num
      when '<=' then a_num <= e_num
      when '!=' then a_num != e_num
      else a_num == e_num
      end
    else
      case operator
      when 'contains' then actual.downcase.include?(expected.downcase)
      when '!=' then actual.casecmp(expected) != 0
      else actual.casecmp(expected).zero?
      end
    end
  end

  def aggregate(op, rows, col)
    return 'No identifiqué la columna numérica.' if col.nil?

    nums = rows.filter_map { |r| Float(r[col].to_s.delete(','), exception: false) }
    return 'No hay valores numéricos en esa columna.' if nums.empty?

    result = case op
             when 'sum' then nums.sum
             when 'avg' then (nums.sum / nums.size)
             when 'min' then nums.min
             when 'max' then nums.max
             end
    format_number(result)
  end

  def list_rows(rows)
    return 'No hay filas que coincidan.' if rows.empty?

    shown = rows.first(MAX_LIST).map.with_index(1) do |r, n|
      "#{n}. #{r.map { |h, v| "#{h}: #{v}" }.join(' · ')}"
    end.join("\n")
    extra = rows.size > MAX_LIST ? "\n… y #{rows.size - MAX_LIST} más." : ''
    "#{shown}#{extra}"
  end

  def resolve_header(name, headers)
    return nil if name.blank?

    headers.find { |h| h.casecmp(name.to_s).zero? } || name
  end

  def format_number(num)
    num == num.to_i ? num.to_i.to_s : format('%.2f', num)
  end

  # --- OpenAI chat (key per-cuenta) -------------------------------------------
  def openai_chat(messages, json: false)
    api_key = openai_api_key
    return nil unless api_key

    body = { model: 'gpt-4o-mini', messages: messages, temperature: 0 }
    body[:response_format] = { type: 'json_object' } if json

    response = HTTParty.post(
      'https://api.openai.com/v1/chat/completions',
      headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
      body: body.to_json,
      timeout: 30
    )
    return nil unless response.success?

    response.parsed_response.dig('choices', 0, 'message', 'content')
  end

  def openai_api_key
    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end
end
