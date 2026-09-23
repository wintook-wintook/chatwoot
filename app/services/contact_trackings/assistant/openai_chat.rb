# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA LLAMADA A OPENAI
# ================================================================================
# El transporte del Asistente, aparte de la entrevista: armar el pedido, mandarlo y
# devolver el JSON que contestó el modelo, o nil. Nada más.
#
# Salió de InterviewService cuando la entrevista pasó a tener tres bucles de
# corrección (comprobador, ruteo y edición): la orquestación y el HTTP juntos ya no
# se leían.
#
# Devuelve nil ante CUALQUIER falla —HTTP, timeout, JSON inválido, respuesta
# cortada— y la registra. Quien llama decide qué hacer con un nil; lo que no puede
# pasar es que una falla de red se lea como "el modelo no entregó nada".
# ================================================================================

class ContactTrackings::Assistant::OpenaiChat
  API_URL = 'https://api.openai.com/v1/chat/completions'
  # ⚠ Estaba en 90. Editando un Entrenamiento de 17.066 caracteres (el v6.11) la
  # llamada tardó 40 y 52 segundos medidos el 15/09/2026, y un prompt más largo tarda
  # más. 180 deja margen sin pasar el límite del proxy (300 s en develop).
  READ_TIMEOUT = 180

  # Tokens de la última llamada, como los informa OpenAI ({"prompt_tokens"=>…,
  # "completion_tokens"=>…}). Para medir lo que cuesta leer un encargo (ver
  # AgentBriefDigestJob); nil si la llamada falló.
  attr_reader :last_usage

  # api_key: la clave ya leída, para quien llama desde un hilo que no debe tocar la base
  # (BriefMerger).
  def initialize(account:, inbox: nil, api_key: nil)
    @account = account
    @inbox = inbox
    @api_key = api_key
  end

  def api_key
    @api_key ||= @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
  end

  # max_tokens: para quien necesite más salida que un Entrenamiento (BriefMerger).
  def call(history, max_tokens: nil)
    body = {
      model: ContactTrackings::EngineConfig.model_for(@inbox, :authoring_assistant),
      messages: history,
      temperature: 0.2,
      max_tokens: max_tokens || ContactTrackings::EngineConfig.max_tokens_for(:authoring_assistant),
      response_format: { type: 'json_object' }
    }

    parse(post(body))
  end

  private

  def post(body)
    @last_usage = nil
    response = http_client.request(build_request(body))
    return failure("HTTP #{response.code}: #{response.body.to_s[0, 300]}") unless response.is_a?(Net::HTTPSuccess)

    datos = JSON.parse(response.body)
    @last_usage = datos['usage']
    choice = datos.dig('choices', 0)
    # Cortada por el tope de tokens: el JSON viene a la mitad. Se nombra acá porque
    # si no, el log dice "no es JSON" y no se entiende que falta subir el tope.
    return failure('respuesta cortada por max_tokens: el Entrenamiento no entró entero') if choice&.dig('finish_reason') == 'length'

    choice&.dig('message', 'content')
  rescue StandardError => e
    failure(e.message)
  end

  def parse(content)
    return nil if content.blank?

    JSON.parse(content)
  rescue JSON::ParserError => e
    failure("respuesta no es JSON: #{e.message}")
  end

  def http_client
    require 'net/http'
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = READ_TIMEOUT
    http
  end

  def build_request(body)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json
    request
  end

  def uri
    @uri ||= URI(API_URL)
  end

  def failure(detail)
    Rails.logger.error("[Asistente] #{detail}")
    nil
  end
end
