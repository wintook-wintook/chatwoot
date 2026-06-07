# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3A — Infraestructura de IA
# ================================================================================
# Servicio base: Cases::Ai::BaseService
#
# Cliente común de chat-completion para todas las acciones de IA del Gestor de
# Tickets (clasificación, respuesta sugerida, resumen, etc.). Centraliza:
#   - obtención de la API key (reusa el hook `openai` de la cuenta, igual que KBase)
#   - llamada de chat-completion (modelo gpt-4o-mini por env)
#   - salida estructurada JSON (response_format json_object) → parseo seguro
#   - tolerancia a fallos: cualquier error/timeout devuelve nil y NO rompe el flujo
#
# Las subclases (Cases::Ai::Classifier, etc.) solo definen el prompt y qué hacen
# con la respuesta.
# ================================================================================

class Cases::Ai::BaseService
  API_URL = 'https://api.openai.com/v1/chat/completions'
  DEFAULT_MODEL = 'gpt-4o-mini'
  READ_TIMEOUT = 45

  def initialize(account:)
    @account = account
  end

  # ¿La cuenta puede usar IA? (hay key configurada)
  def available?
    api_key.present?
  end

  protected

  # Llama a la API de chat-completion.
  #   system: instrucción de sistema (rol/comportamiento)
  #   user:   contenido del usuario (los datos del ticket)
  #   json:   si true, exige salida JSON y la parsea a Hash (nil si no parsea)
  # Devuelve el contenido (String) o el Hash parseado, o nil ante cualquier fallo.
  def chat(system:, user:, json: false, temperature: 0.2, max_tokens: 600)
    key = api_key
    return nil if key.blank?

    body = {
      model:       model,
      messages:    [
        { role: 'system', content: system },
        { role: 'user',   content: user }
      ],
      temperature: temperature,
      max_tokens:  max_tokens
    }
    body[:response_format] = { type: 'json_object' } if json

    content = post(key, body)
    return nil if content.blank?

    json ? safe_parse(content) : content
  end

  private

  def post(key, body)
    require 'net/http'

    uri               = URI(API_URL)
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = READ_TIMEOUT

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{key}"
    request['Content-Type']  = 'application/json'
    request.body             = body.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("[Cases::Ai] OpenAI HTTP #{response.code}: #{response.body.to_s[0, 300]}")
      return nil
    end
    JSON.parse(response.body).dig('choices', 0, 'message', 'content')&.strip
  rescue StandardError => e
    Rails.logger.error("[Cases::Ai] OpenAI error: #{e.message}")
    nil
  end

  def safe_parse(content)
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error("[Cases::Ai] JSON parse error: #{e.message} — #{content.to_s[0, 200]}")
    nil
  end

  def model
    ENV.fetch('OPENAI_GPT_MODEL', DEFAULT_MODEL)
  end

  # Reusa la integración OpenAI de la cuenta (mismo patrón que KnowledgeBaseResponseService).
  def api_key
    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end
end
