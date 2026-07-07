# frozen_string_literal: true

# @query_databases — Modo B: traduce una pregunta libre del usuario a UNA consulta
# predefinida (allowlist, `ai_enabled`) vía function calling de OpenAI, la corre con
# QueryRunner (solo lectura, bind seguro) y redacta una respuesta en lenguaje natural.
# La IA nunca ve ni escribe SQL: solo elige la función (consulta) y rellena parámetros.
class ExternalDb::AiQueryService
  Result = Struct.new(:answer, :query_name, :params, :rows, keyword_init: true)

  OPENAI_URL = 'https://api.openai.com/v1/chat/completions'
  MODEL = 'gpt-4o-mini'

  # Parámetro que identifica al cliente y custom_attribute donde se guarda en el contacto.
  RFC_PARAM = 'rfc'
  CONTACT_RFC_ATTR = 'erp_rfc'
  # RFC mexicano: 3-4 letras + 6 dígitos (fecha) + 2-3 alfanuméricos (homoclave).
  RFC_REGEX = /\b([A-ZÑ&]{3,4}\d{6}[A-Z0-9]{2,3})\b/i

  def initialize(connection, question, contact: nil)
    @connection = connection
    @account = connection.account
    @question = question.to_s
    @contact = contact
  end

  def perform
    queries = @connection.external_db_queries.active.ai_enabled.to_a
    return error_result('no hay consultas habilitadas para IA en esta conexión') if queries.empty?

    api_key = openai_api_key
    return error_result('la cuenta no tiene integración OpenAI activa') if api_key.blank?

    # Si el mensaje trae un RFC, lo guardamos en el contacto para próximas consultas.
    capture_rfc_from_message
    answer_question(queries, api_key)
  rescue StandardError => e
    Rails.logger.error "[ExternalDb::AiQuery] #{e.class}: #{e.message}"
    error_result(e.message)
  end

  private

  def answer_question(queries, api_key)
    tool_call = pick_query(queries, api_key)
    return error_result('no encontré una consulta que responda eso') if tool_call.nil?

    query = queries.find { |q| q.name == tool_call[:name] }
    return error_result('la IA eligió una consulta inexistente') if query.nil?

    # Cadena de resolución del RFC (opción 1+3): mensaje → contacto → pedirlo.
    # resolve_rfc! devuelve una respuesta pidiendo el RFC, o nil si ya se resolvió.
    resolve_rfc!(query, tool_call[:args]) || run_and_answer(query, tool_call, api_key)
  end

  def run_and_answer(query, tool_call, api_key)
    result = ExternalDb::QueryRunner.new(query, tool_call[:args]).perform
    Result.new(
      answer: phrase_answer(query, result, api_key),
      query_name: query.name,
      params: tool_call[:args],
      rows: result.rows
    )
  end

  # Resuelve el parámetro :rfc cuando la consulta lo requiere:
  # 1) si la IA lo extrajo del mensaje, se usa (y se guarda en el contacto);
  # 2) si no, se toma del custom_attribute del contacto;
  # 3) si tampoco hay, se pide por chat (no se corre la consulta).
  def resolve_rfc!(query, args)
    return nil unless query_needs_rfc?(query)

    provided = args[RFC_PARAM].to_s.strip.upcase
    if provided.present?
      args[RFC_PARAM] = provided
      persist_rfc(provided)
      return nil
    end

    stored = contact_rfc
    if stored.present?
      args[RFC_PARAM] = stored
      return nil
    end

    Result.new(answer: ask_for_rfc_message, query_name: nil, params: {}, rows: [])
  end

  def query_needs_rfc?(query)
    Array(query.params_schema).any? { |p| (p['key'] || p[:key]).to_s == RFC_PARAM }
  end

  def contact_rfc
    @contact&.custom_attributes&.dig(CONTACT_RFC_ATTR).to_s.strip.upcase.presence
  end

  def capture_rfc_from_message
    return if @contact.nil?

    match = @question.match(RFC_REGEX)
    persist_rfc(match[1].upcase) if match
  end

  def persist_rfc(rfc)
    return if @contact.nil? || rfc.blank? || contact_rfc == rfc

    ensure_rfc_definition!
    attrs = (@contact.custom_attributes || {}).merge(CONTACT_RFC_ATTR => rfc)
    @contact.update(custom_attributes: attrs)
  rescue StandardError => e
    Rails.logger.warn "[ExternalDb::AiQuery] no se pudo guardar el RFC en el contacto: #{e.message}"
  end

  # Las definiciones de custom attribute son POR CUENTA (unique por
  # account_id + attribute_model). Auto-provisionamos `erp_rfc` en la cuenta la
  # primera vez que se guarda, para que aparezca con nombre "RFC" en el panel del
  # contacto. No afecta a otras cuentas.
  def ensure_rfc_definition!
    return if @account.custom_attribute_definitions
                      .exists?(attribute_key: CONTACT_RFC_ATTR, attribute_model: :contact_attribute)

    @account.custom_attribute_definitions.create!(
      attribute_key: CONTACT_RFC_ATTR,
      attribute_display_name: 'RFC',
      attribute_display_type: :text,
      attribute_model: :contact_attribute,
      attribute_description: 'RFC del cliente para consultas al ERP (bot cobrador).'
    )
  rescue ActiveRecord::RecordNotUnique
    # Creada en paralelo por otro job/mensaje: la damos por buena.
  end

  def ask_for_rfc_message
    'Para consultar tu información necesito tu RFC. ¿Me lo compartes, por favor?'
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
