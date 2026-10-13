# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — LAS LLAMADAS DEL MOTOR A OPENAI, SIN FALLAR EN SILENCIO (P3a)
# ================================================================================
# Las cuatro llamadas del camino de la respuesta al cliente —elegir la ruta, entender
# una fecha, la respuesta conversacional y la de Base de Conocimiento— armaban el
# pedido a mano y leían `choices[0].message.content` sin mirar si OpenAI había
# aceptado. Un rechazo (modelo no permitido, parámetro que el modelo no acepta, clave
# sin saldo) llega como HTTP 4xx con un JSON de error: el contenido salía vacío, no
# quedaba nada en el log, y en la respuesta conversacional el cliente se quedaba sin
# respuesta (docs/diagnostico_asistente_agentes_ia_plan.md, P3).
#
# Esto hace la llamada y devuelve el texto, o nil con `error` explicando el porqué —el
# mensaje real de OpenAI— y lo registra. Quien llama decide qué hacer con el nil (la
# respuesta conversacional deja una nota privada en la conversación: decisión D17).
#
# No cambia el pedido: el cuerpo lo sigue armando cada llamada. Cuando todo funciona,
# el resultado es el mismo de antes.
#
# P3b — LOS PARÁMETROS SEGÚN EL MODELO (`chat`): gpt-4o y sus pares reciben `max_tokens` y
# `temperature`, como siempre; la familia gpt-5 no los acepta (HTTP 400 medido) y recibe
# `max_completion_tokens` —el tope de hoy más un margen, porque el razonamiento cuenta
# dentro— y un nivel de razonamiento por uso. Medido el 13/10/2026 con la respuesta real
# de la conversación 403: gpt-5.4-mini y gpt-5.5 contestan en 1,5–2,6 s con none o low.
# Qué usos pueden recibir gpt-5 lo decide EngineConfig (D18: solo los que contestan).
# ================================================================================

class ContactTrackings::EngineOpenai
  API_URL = 'https://api.openai.com/v1/chat/completions'
  REASONING_MODEL_RE = /\A(gpt-5|o\d)/
  # Lo que puede pensar gpt-5 además del tope de la respuesta. No se cobra si no se usa.
  REASONING_MARGIN = 1500
  # Contestar al cliente piensa un poco; clasificar y extraer datos, nada.
  EFFORT = { conversational: 'low', scheduled: 'low', kbase: 'low' }.freeze
  DEFAULT_EFFORT = 'none'

  attr_reader :error

  def self.limits(model, purpose:, max_tokens:, temperature:)
    return { max_tokens: max_tokens, temperature: temperature } unless model.to_s.match?(REASONING_MODEL_RE)

    { max_completion_tokens: max_tokens + REASONING_MARGIN, reasoning_effort: EFFORT.fetch(purpose.to_sym, DEFAULT_EFFORT) }
  end

  # purpose: para el log (:router, :datetime, :conversational, :kbase).
  def initialize(api_key, purpose:, timeout:)
    @api_key = api_key
    @purpose = purpose
    @timeout = timeout
  end

  # El pedido con los parámetros que acepta ese modelo (P3b). json: respuesta en JSON.
  def chat(model:, messages:, max_tokens:, temperature:, json: false)
    body = { model: model, messages: messages }
    body[:response_format] = { type: 'json_object' } if json
    complete(body.merge(self.class.limits(model, purpose: @purpose, max_tokens: max_tokens, temperature: temperature)))
  end

  # body: el pedido ya armado. Devuelve el texto del modelo o nil.
  def complete(body)
    @error = nil
    response = http.request(request(body))
    datos = parse(response.body)
    return failure("HTTP #{response.code}: #{openai_message(datos, response)}") unless response.is_a?(Net::HTTPSuccess)

    content = datos.dig('choices', 0, 'message', 'content')
    return failure("respuesta vacía (finish_reason: #{datos.dig('choices', 0, 'finish_reason').inspect})") if content.blank?

    content
  rescue StandardError => e
    failure("#{e.class}: #{e.message}")
  end

  private

  def http
    require 'net/http'
    uri = URI(API_URL)
    Net::HTTP.new(uri.host, uri.port).tap do |h|
      h.use_ssl = true
      h.read_timeout = @timeout
    end
  end

  def request(body)
    Net::HTTP::Post.new(URI(API_URL)).tap do |r|
      r['Authorization'] = "Bearer #{@api_key}"
      r['Content-Type'] = 'application/json'
      r.body = body.to_json
    end
  end

  def parse(texto)
    JSON.parse(texto.to_s)
  rescue JSON::ParserError
    {}
  end

  def openai_message(datos, response)
    datos.dig('error', 'message').presence || response.body.to_s[0, 200]
  end

  def failure(detalle)
    @error = detalle.to_s.truncate(300)
    Rails.logger.error "[TrackingBot/OpenAI] ❌ #{@purpose}: #{@error}"
    nil
  end
end
