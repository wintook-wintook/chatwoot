# ================================================================================
# proyecto@ai_agent_assistant - F7
# ================================================================================
# Servicio: AiAgentAssistant::SandboxService
# Descripción: El turno en vivo del probador. Ejecuta los motores REALES con el
#              envío desconectado.
#
# Hoy la única forma de probar un Agente IA es crear un seguimiento de verdad y
# esperar al cron. Esto arma el mismo system prompt que el motor (PromptBuilder),
# llama a OpenAI con la clave de la cuenta, clasifica con el RouterService real y
# detecta las palabras clave con el mismo matcher que el motor — pero no crea
# ningún Message, no toca el canal, no agenda, no levanta tickets y no muta nada.
#
# Los efectos se devuelven como `would_have`: «esto habría pasado». Es la
# diferencia entre probar y adivinar.
#
# Devuelve además el consumo REAL de tokens contra el tope. Es la evidencia
# directa de T1: un prompt de 8 000 caracteres entrando en una caja de 150.
# ================================================================================

class AiAgentAssistant::SandboxService < Cases::Ai::BaseService
  SIMULATED_CONTACT_NAME = 'Juan Pérez'.freeze

  # Banderas del prompt → efecto que el motor dispararía y que aquí no se ejecuta.
  EFFECT_BY_CAPABILITY = { agendar_calendar: 'book_appointment', crear_ticket: 'create_ticket' }.freeze

  # El router solo lee `content` del mensaje; no hace falta un Message de verdad
  # (y crear uno sería justo el efecto que este servicio existe para no tener).
  SimulatedMessage = Struct.new(:content)

  def initialize(template, contact_name: nil, attempt: 1)
    super(account: template.account)
    @template = template
    @contact_name = contact_name.presence || SIMULATED_CONTACT_NAME
    @attempt = [attempt.to_i, 1].max
  end

  # El mensaje inicial del intento n. Sirve para ver si los reintentos se repiten.
  def opening
    return unavailable if api_key.blank?

    section = preview[:scheduled]
    result  = complete(section, system: section[:system], user: section[:user])

    result.merge('would_have' => outgoing_effects(result['text']))
  end

  # La respuesta a un mensaje del cliente, con la ruta que habría tomado el motor.
  def reply(message, history: '')
    return unavailable if api_key.blank?

    section = preview(message: message)[:conversational]
    result  = complete(section, system: section[:system], user: section[:user])

    result.merge(
      'route' => classify(message, history),
      'keyword_action' => keyword_match(message, 'incoming'),
      'would_have' => incoming_effects(message, result['text'])
    )
  end

  private

  attr_reader :template, :contact_name, :attempt

  def preview(message: nil)
    AiAgentAssistant::PromptPreview.new(
      template, attempt: attempt, contact_name: contact_name, message: message
    ).call
  end

  # Seguimiento en memoria: lo que el RouterService y el matcher de palabras clave
  # necesitan para trabajar, sin que exista ningún seguimiento de verdad.
  def simulated_tracking
    @simulated_tracking ||= ContactTracking.new(
      account: template.account, inbox: template.inbox,
      objective: template.objective, ai_context: template.ai_context,
      complementary_prompt: template.complementary_prompt,
      keyword_actions: template.keyword_actions
    )
  end

  # El router real, tal cual lo corre el motor. Es de solo lectura: clasifica y ya.
  def classify(message, history)
    ContactTrackings::RouterService.new(
      simulated_tracking, SimulatedMessage.new(message), api_key,
      kbase_available: kbase_available?, recent_messages: history
    ).classify
  rescue StandardError => e
    Rails.logger.warn("[AiAgentAssistant] el router no pudo clasificar: #{e.message}")
    nil
  end

  # El mismo matcher del motor, en su versión que NO ejecuta.
  def keyword_match(content, direction)
    entry = ContactTrackings::KeywordActionService.new(simulated_tracking, content, direction).match
    entry&.slice('keyword', 'action', 'direction')
  end

  def kbase_available?
    AiAgentAssistant::Capabilities.detect(template.complementary_prompt.to_s)
                                  .any? { |capability| capability[:kind] == :search }
  end

  # «Esto habría pasado»: los efectos que el motor dispararía y que aquí no se ejecutan.
  def outgoing_effects(text)
    effects = []
    effects << 'send_message' if text.present?
    effects << 'consume_attempt'
    effects.concat(keyword_effects(text.to_s, 'outgoing'))
  end

  def incoming_effects(message, text)
    effects = ['send_message']
    effects << 'search_knowledge' if kbase_available?
    effects.concat(capability_effects)
    effects << 'send_attachment' if text.to_s.match?(ContactTrackingResponseAnalyzerJob::ATTACHMENT_DIRECTIVE)
    effects.concat(keyword_effects(message, 'incoming'))
  end

  def capability_effects
    detected = AiAgentAssistant::Capabilities.detect(template.complementary_prompt.to_s).pluck(:key)
    EFFECT_BY_CAPABILITY.filter_map { |key, effect| effect if detected.include?(key) }
  end

  def keyword_effects(content, direction)
    match = keyword_match(content, direction)
    match ? ["keyword_#{match['action']}"] : []
  end

  # Petición propia en vez de la del padre porque aquí SÍ importa el consumo real:
  # `usage` y `finish_reason` son la evidencia de que el tope corta la respuesta, y
  # el cliente compartido solo devuelve el texto.
  def complete(section, system:, user:)
    body = {
      model: section[:model],
      messages: [{ role: 'system', content: system }, { role: 'user', content: user }],
      max_tokens: section[:max_tokens],
      temperature: 0.7
    }
    parsed = request(body)
    return failed(section) if parsed.nil?

    choice = parsed.dig('choices', 0) || {}
    used   = parsed.dig('usage', 'completion_tokens').to_i

    {
      'text' => choice.dig('message', 'content').to_s.strip,
      'model' => section[:model],
      'max_tokens' => section[:max_tokens],
      'tokens_used' => used,
      'truncated' => choice['finish_reason'] == 'length',
      'system_chars' => section[:system_chars],
      'notes' => section[:notes]
    }
  end

  def request(body)
    require 'net/http'

    uri  = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("[AiAgentAssistant] probador: #{e.message}")
    nil
  end

  def failed(section)
    { 'text' => nil, 'model' => section[:model], 'max_tokens' => section[:max_tokens],
      'tokens_used' => 0, 'truncated' => false, 'system_chars' => section[:system_chars],
      'notes' => section[:notes], 'error' => 'model_unavailable' }
  end

  def unavailable
    { 'text' => nil, 'tokens_used' => 0, 'would_have' => [], 'error' => 'openai_not_configured' }
  end
end
