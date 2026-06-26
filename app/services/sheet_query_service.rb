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
    refresh_if_live
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

  DEFAULT_LIVE_TTL = 60 # segundos

  # Modo "en vivo" (config['live']): mantiene la foto local fresca SIN re-leer la hoja
  # en cada consulta. Solo cuando pasó el TTL pide el modifiedTime (dato liviano) y,
  # si cambió, re-lee las filas una vez. Si Google falla, cae a la foto local.
  def refresh_if_live
    return unless @source.config['live']

    ttl  = (@source.config['live_ttl'] || DEFAULT_LIVE_TTL).to_i
    last = @source.config['live_checked_at']
    return if last.present? && (Time.zone.parse(last) > ttl.seconds.ago)

    integration = live_integration
    return unless integration

    svc      = GoogleSheetsService.new(integration)
    file_id  = @source.config['file_id']
    remote_m = svc.file_metadata(file_id)['modifiedTime']
    updates  = { 'live_checked_at' => Time.current.iso8601 }

    if remote_m != @source.config['modified_time']
      replace_rows(svc.read_table(file_id, range: @source.config['sheet_range']))
      updates['modified_time'] = remote_m
      Rails.logger.info "[SheetQueryService] 🔄 hoja '#{@source.name}' cambió → foto refrescada en vivo"
    end
    @source.update(config: @source.config.merge(updates))
  rescue StandardError => e
    Rails.logger.warn "[SheetQueryService] refresco en vivo falló (#{e.message.to_s.truncate(120)}) → uso foto local"
  end

  def replace_rows(table)
    @source.google_sheet_rows.delete_all
    now = Time.current
    records = table[:rows].each_with_index.map do |row, index|
      { account_id: @account.id, knowledge_source_id: @source.id, row_index: index,
        data: row, created_at: now, updated_at: now }
    end
    GoogleSheetRow.insert_all(records) if records.any?
  end

  def live_integration
    scope = UserCalendarIntegration.where(account_id: @account.id)
    id    = @source.config['integration_id']
    (id.present? && scope.find_by(id: id)) || scope.first
  end

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
      { "operations": [ { "op": "sum|avg|min|max|count|filter|list", "column": "<encabezado o null>" } ],
        "filters": [ { "column": "<encabezado>", "operator": "=|!=|>|<|>=|<=|contains|in", "value": "<texto o lista>" } ] }
      Reglas: usa exactamente los encabezados dados. Para "cuántos" usa count. Para "cuáles/lista" usa list.
      Si la pregunta solo describe facturas con condiciones y NO dice qué calcular, usá op "count".
      Para "X o Y" sobre el mismo campo (ej. "México y Argentina"), usá operator "in" con value como lista: ["México","Argentina"].
      Si la pregunta combina condiciones de DISTINTOS campos unidas por "o"/grupos separados
      (ej. "pendientes en México y pagadas en Argentina" = un grupo {estado=Pendiente, pais=México}
      O otro grupo {estado=Pagada, pais=Argentina}), usá "filter_groups": [ [cond, cond], [cond, cond] ]
      en lugar de "filters". Cada grupo es un AND de condiciones y los grupos se unen con OR.
      Para sumar/promediar/máximo/mínimo usa la columna numérica correspondiente. Si no hay filtros, "filters": [].
      Si la pregunta pide VARIAS cosas a la vez (ej. "cuántas y cuánto suman"), incluí UNA entrada por cada
      cálculo en "operations". Los "filters" aplican a todas las operaciones de la pregunta.
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
    ops = operations_of(spec).map { |o| o['op'] }
    return nil if ops.empty? || ops.any? { |o| !OPS.include?(o) }

    spec
  rescue JSON::ParserError
    nil
  end

  # Normaliza el spec a una lista de operaciones. Acepta el esquema nuevo
  # ("operations": [...]) y el viejo (op/column sueltos) por compatibilidad.
  def operations_of(spec)
    list = spec['operations']
    return list if list.is_a?(Array) && list.any?

    [{ 'op' => spec['op'], 'column' => spec['column'] }]
  end

  # --- 2) Ruby: ejecuta la spec de forma determinista -------------------------
  # Una o varias operaciones comparten los mismos filtros. Con una sola operación
  # devuelve el valor pelado (compatibilidad); con varias, etiqueta cada resultado.
  def execute(spec, rows, headers)
    filtered = filter_rows(rows, spec, headers)
    results = operations_of(spec).filter_map do |o|
      col   = resolve_header(o['column'], headers)
      value = run_op(o['op'], filtered, col)
      next if value.nil?

      [op_label(o['op']), value]
    end
    return nil if results.empty?
    return results.first.last if results.size == 1

    results.map { |label, value| "#{label}: #{value}" }.join("\n")
  end

  def run_op(op, filtered, col)
    case op
    when 'count' then filtered.size.to_s
    when 'sum', 'avg', 'min', 'max' then aggregate(op, filtered, col)
    when 'filter', 'list' then list_rows(filtered)
    end
  end

  def op_label(op)
    { 'count' => 'Cantidad', 'sum' => 'Suma', 'avg' => 'Promedio',
      'min' => 'Mínimo', 'max' => 'Máximo', 'filter' => 'Listado', 'list' => 'Listado' }[op] || op
  end

  # Grupos de filtros: una fila pasa si coincide con ALGÚN grupo (OR entre grupos),
  # y dentro de un grupo deben cumplirse todas las condiciones (AND). Permite
  # "pendientes en México y pagadas en Argentina" = {Pendiente,México} O {Pagada,Argentina}.
  # Acepta el esquema nuevo ("filter_groups") y el plano ("filters") por compatibilidad.
  def filter_rows(rows, spec, headers)
    groups = filter_groups(spec)
    return rows if groups.empty?

    rows.select { |row| groups.any? { |group| group_matches?(row, group, headers) } }
  end

  def filter_groups(spec)
    groups = spec['filter_groups']
    return groups if groups.is_a?(Array) && groups.any?

    flat = spec['filters']
    flat.is_a?(Array) && flat.any? ? [flat] : []
  end

  # Dentro de un grupo: sobre la MISMA columna, las igualdades se interpretan como
  # alternativas (OR) — "México y Argentina" = México O Argentina. Entre columnas
  # distintas es AND. Los operadores de rango (>, <, etc.) siempre son AND, para no
  # romper consultas como "monto > 1000 y < 5000".
  def group_matches?(row, filters, headers)
    filters.group_by { |f| resolve_header(f['column'], headers) }.all? do |col, col_filters|
      next true if col.nil?

      actual = row[col].to_s
      eq, other = col_filters.partition { |f| equality_filter?(f) }
      (eq.empty? || eq.any? { |f| match_filter(actual, f) }) &&
        other.all? { |f| match_filter(actual, f) }
    end
  end

  def equality_filter?(filter)
    op = filter['operator'].to_s
    op.empty? || op == '=' || op == 'in'
  end

  # Acepta value escalar o lista (operator "in" o varios valores) → OR de igualdades.
  def match_filter(actual, filter)
    op = filter['operator'].to_s
    values = Array(filter['value'])
    return values.any? { |v| compare(actual, '=', v.to_s) } if op == 'in' || values.size > 1

    compare(actual, op.presence || '=', values.first.to_s)
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
