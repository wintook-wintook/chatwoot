# frozen_string_literal: true

# @query_databases — Modo B: traduce una pregunta libre del usuario a UNA consulta
# predefinida (allowlist, `ai_enabled`) vía function calling de OpenAI, la corre con
# QueryRunner (solo lectura, bind seguro) y redacta una respuesta en lenguaje natural.
# La IA nunca ve ni escribe SQL: solo elige la función (consulta) y rellena parámetros.
class ExternalDb::AiQueryService
  Result = Struct.new(:answer, :query_name, :params, :rows, keyword_init: true)

  OPENAI_URL = 'https://api.openai.com/v1/chat/completions'
  MODEL = 'gpt-4o-mini'

  def initialize(connection, question)
    @connection = connection
    @account = connection.account
    @question = question.to_s
  end

  def perform
    queries = @connection.external_db_queries.active.ai_enabled.to_a
    return error_result('no hay consultas habilitadas para IA en esta conexión') if queries.empty?

    api_key = openai_api_key
    return error_result('la cuenta no tiene integración OpenAI activa') if api_key.blank?

    tool_call = pick_query(queries, api_key)
    return error_result('no encontré una consulta que responda eso') if tool_call.nil?

    run_and_answer(queries, tool_call, api_key)
  rescue StandardError => e
    Rails.logger.error "[ExternalDb::AiQuery] #{e.class}: #{e.message}"
    error_result(e.message)
  end

  private

  def run_and_answer(queries, tool_call, api_key)
    query = queries.find { |q| q.name == tool_call[:name] }
    return error_result('la IA eligió una consulta inexistente') if query.nil?

    result = ExternalDb::QueryRunner.new(query, tool_call[:args]).perform
    Result.new(
      answer: phrase_answer(query, result, api_key),
      query_name: query.name,
      params: tool_call[:args],
      rows: result.rows
    )
  end

  # 1ª llamada: la IA elige la función (consulta) y rellena parámetros.
  def pick_query(queries, api_key)
    body = {
      model: MODEL,
      messages: [
        { role: 'system', content: 'Sos un asistente de cobranza. Elegí la función que ' \
                                   'responde la pregunta del usuario y completá sus parámetros.' },
        { role: 'user', content: @question }
      ],
      tools: queries.map { |q| tool_for(q) },
      tool_choice: 'auto',
      temperature: 0
    }
    call = openai(body, api_key)&.dig('choices', 0, 'message', 'tool_calls', 0, 'function')
    return nil if call.nil?

    { name: call['name'], args: safe_json(call['arguments']) }
  end

  # 2ª llamada: redacta la respuesta natural a partir de las filas reales.
  def phrase_answer(query, result, api_key)
    context = result.rows.first(20).to_json
    body = {
      model: MODEL,
      messages: [
        { role: 'system', content: 'Respondé en español, claro y breve, usando SOLO los datos ' \
                                   'provistos. Montos con 2 decimales. Si no hay filas, decilo.' },
        { role: 'user', content: "Pregunta: #{@question}\nConsulta: #{query.name}\nDatos: #{context}" }
      ],
      temperature: 0.2
    }
    openai(body, api_key)&.dig('choices', 0, 'message', 'content').presence ||
      "Encontré #{result.row_count} resultado(s)."
  end

  def tool_for(query)
    {
      type: 'function',
      function: {
        name: query.name,
        description: query.description.presence || query.name,
        parameters: {
          type: 'object',
          properties: param_properties(query),
          required: required_params(query)
        }
      }
    }
  end

  def param_properties(query)
    Array(query.params_schema).each_with_object({}) do |p, acc|
      key = p['key'] || p[:key]
      next if key.blank?

      acc[key] = { type: json_type(p['type'] || p[:type]), description: (p['label'] || p[:label]).to_s }
    end
  end

  def required_params(query)
    Array(query.params_schema).select { |p| p['required'] || p[:required] }
                              .filter_map { |p| p['key'] || p[:key] }
  end

  def json_type(type)
    case type.to_s
    when 'integer' then 'integer'
    when 'number'  then 'number'
    else 'string'
    end
  end

  def openai(body, api_key)
    response = HTTParty.post(
      OPENAI_URL,
      headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
      body: body.to_json,
      timeout: 30
    )
    response.success? ? response.parsed_response : nil
  end

  def safe_json(str)
    JSON.parse(str.to_s)
  rescue JSON::ParserError
    {}
  end

  def openai_api_key
    @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
  end

  def error_result(message)
    Result.new(answer: message, query_name: nil, params: {}, rows: [])
  end
end
