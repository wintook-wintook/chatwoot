# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — LA IA LLENA LOS "?" DE UNA {{consulta:}}
# ================================================================================
# Plan: docs/erp_productos_plan.md (§3.2). Dada la consulta, los parámetros que pidió el
# agente con "?" y lo que escribió el cliente, devuelve los valores para esos parámetros
# — y SOLO para esos: los fijos no se le muestran, no los puede cambiar.
#
#   { use: true, params: { 'texto' => 'laptop hp', 'precio_max' => '15000' } }
#   { use: false, params: {} }   el mensaje no pide nada que esta consulta responda
#   nil                          no hubo respuesta usable (sin key, error, JSON inválido)
#
# La IA nunca ve ni escribe SQL: ve el nombre, la descripción y las etiquetas de los
# parámetros. Modelo del inbox con piso de propósito :router (tarea corta, JSON).
# ================================================================================
class ExternalDb::AskedParams
  API_URL = 'https://api.openai.com/v1/chat/completions'
  HISTORY_TURNS = 3

  def initialize(query:, asked:, question:, inbox: nil, history: [])
    @query = query
    @asked = asked
    @question = question.to_s
    @account = query.account
    @inbox = inbox
    @history = Array(history).last(HISTORY_TURNS)
  end

  def call
    return nil if api_key.blank? || @asked.empty?

    answer = request
    return nil unless answer.is_a?(Hash)

    { use: answer['usar'] != false, params: clean(answer['parametros']) }
  end

  private

  # Solo los parámetros pedidos, sin vacíos; todo como texto (el QueryRunner los tipa).
  def clean(values)
    return {} unless values.is_a?(Hash)

    values.slice(*@asked).transform_values { |v| v.is_a?(Array) ? v.join(' ') : v.to_s.strip }.compact_blank
  end

  def asked_specs
    Array(@query.params_schema).select { |p| @asked.include?((p['key'] || p[:key]).to_s) }
  end

  def instructions
    params = asked_specs.map { |p| "- #{p['key']}: #{p['label'] || p['key']} (#{p['type'] || 'string'})" }.join("\n")
    <<~PROMPT
      Eres un extractor de datos para una consulta a un sistema administrativo (ERP).
      Consulta: #{@query.name} — #{@query.description}
      Parámetros que tienes que llenar con lo que escribió el cliente:
      #{params}

      Reglas:
      - Decide por el ÚLTIMO mensaje del cliente. Los anteriores sirven SOLO para completar una
        búsqueda que ese último mensaje continúa ("¿y de menos de 300?", "¿y en azul?").
      - Si el último mensaje no pide ni continúa una búsqueda —agradece, se despide, confirma,
        saluda, da sus datos o habla de otra cosa—, usar = false (medido: con "ok, gracias por la
        info" se repetía la búsqueda del mensaje anterior).
      - Si no dio un dato, OMITE ese parámetro: nunca lo inventes.
      - Números sin símbolos ni comas ("15 mil" → 15000). Sí/no como "si" o "no".
      - Para texto a buscar, solo las palabras que identifican lo que busca
        ("¿tienen laptops hp?" → "laptop hp"), sin saludos ni verbos.
      Responde SOLO JSON: {"usar": true, "parametros": {"clave": "valor"}}
    PROMPT
  end

  def messages
    turns = @history.flat_map { |h| [{ role: 'user', content: h['q'].to_s }, { role: 'assistant', content: h['a'].to_s }] }
    [{ role: 'system', content: instructions }, *turns, { role: 'user', content: @question }]
  end

  def request
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    post = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json')
    post.body = { model: ContactTrackings::EngineConfig.model_for(@inbox, :router), messages: messages, temperature: 0,
                  max_tokens: ContactTrackings::EngineConfig.max_tokens_for(:router),
                  response_format: { type: 'json_object' } }.to_json
    JSON.parse(JSON.parse(http.request(post).body).dig('choices', 0, 'message', 'content').to_s)
  rescue StandardError => e
    Rails.logger.warn "[ExternalDb::AskedParams] #{@query.name}: #{e.message}"
    nil
  end

  def api_key
    @api_key ||= @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
  end
end
