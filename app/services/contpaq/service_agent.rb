# frozen_string_literal: true

# @kbase_contpaq — Cliente del Agente de Servicio CONTPAQi.
#
# Este servicio NO devuelve contexto para que lo redacte un modelo: devuelve la respuesta
# ya escrita y las fuentes que la respaldan. Por eso el resultado se entrega tal cual y la
# rama de kbase no pasa por OpenAI (ver el plan, seccion 1).
#
# Todo es fail-soft: cualquier fallo registra y devuelve un Result sin respuesta, para que
# el turno caiga al conversacional en vez de romper la conversacion.
class Contpaq::ServiceAgent
  # Reintentables: el servicio esta saturado o caido, la peticion en si esta bien.
  RETRIABLE = [429, 500, 502, 503, 504].freeze

  # Esperas entre reintentos. Cortas a proposito: del otro lado hay una persona
  # esperando en un chat, no un proceso batch.
  BACKOFF = [0.5, 2.0].freeze

  # question 8000 · conversation_id 128 · user_id 256 (mas alla, el servicio da 422).
  MAX_QUESTION = 8000
  MAX_CONVERSATION_ID = 128
  MAX_USER_ID = 256

  # El juego que admite conversation_id. La documentacion marca salirse de aca como la
  # causa mas frecuente de un 422 inesperado, asi que se sanea siempre.
  CONVERSATION_ID_ALLOWED = /[^A-Za-z0-9._:-]/

  Result = Struct.new(:answer, :sources, :message_id, :error, keyword_init: true) do
    def ok?
      answer.present?
    end

    # Sin fuentes no se cita nada: son los tres casos que contestan 200 sin ser
    # respuesta (falta el producto, fuera de alcance, saludo).
    def sources?
      sources.present?
    end
  end

  def initialize(source)
    @source  = source
    @config  = source.config.to_h
    @tokens  = Contpaq::TokenProvider.new(source)
    @limiter = Contpaq::RateLimiter.new(source)
  end

  # Unico endpoint sin token: sirve para que un monitor externo confirme que el
  # servicio esta arriba. No valida credenciales ni permisos.
  def ping
    response = request(Net::HTTP::Get, '/ping', body: nil, token: nil)
    response.is_a?(Net::HTTPSuccess) && JSON.parse(response.body)['status'] == 'Healthy'
  rescue StandardError => e
    Rails.logger.error "[CONTPAQi] ❌ /ping: #{e.message}"
    false
  end

  # Pregunta al asistente. `conversation_id` activa la memoria del lado del servicio:
  # con el puesto, el seguimiento ("y como lo cancelo?") lo resuelve CONTPAQi y no
  # hace falta mandarle historial nuestro.
  def answer(question:, user_id:, conversation_id: nil, images: nil)
    payload = build_answer_payload(question, user_id, conversation_id, images)
    return Result.new(error: :invalid_request) if payload.nil?

    response = call_with_retries('/answer', payload)
    return Result.new(error: :unavailable) if response.nil?

    parse_answer(response)
  end

  private

  def build_answer_payload(question, user_id, conversation_id, images)
    text = question.to_s.strip
    if text.blank? || user_id.blank?
      Rails.logger.warn '[CONTPAQi] ⚠️ Falta question o user_id → no se consulta'
      return nil
    end

    payload = { question: text.truncate(MAX_QUESTION), user_id: user_id.to_s.first(MAX_USER_ID) }
    payload[:conversation_id] = sanitize_conversation_id(conversation_id) if conversation_id.present?
    payload[:images] = Array(images) if images.present?
    payload
  end

  def sanitize_conversation_id(raw)
    raw.to_s.gsub(CONVERSATION_ID_ALLOWED, '-').first(MAX_CONVERSATION_ID)
  end

  # Reintenta solo lo que vale la pena. 404/413/422 no se reintentan: la peticion esta
  # mal y va a fallar igual. El 401 se reintenta UNA vez, con token nuevo.
  def call_with_retries(path, payload)
    renewed = false
    attempt = 0

    loop do
      return nil unless @limiter.allow?

      response = request(Net::HTTP::Post, path, body: payload, token: @tokens.token)
      return response if response.is_a?(Net::HTTPSuccess)

      log_failure(path, response)

      case retry_action(response.code.to_i, renewed: renewed, attempt: attempt)
      when :renew then renewed = renew_token!
      when :wait  then attempt = wait_before_retry(attempt)
      else return nil
      end
    end
  rescue StandardError => e
    Rails.logger.error "[CONTPAQi] \u274c #{path}: #{e.message}"
    nil
  end

  # Tira el token vencido para que el reintento pida uno nuevo. Devuelve true, que es
  # lo que marca "ya se renovo una vez": el 401 no se reintenta dos veces.
  def renew_token!
    @tokens.invalidate!
    true
  end

  def wait_before_retry(attempt)
    sleep(BACKOFF[attempt])
    attempt + 1
  end

  # Que hacer con una respuesta fallida: pedir token nuevo, esperar y reintentar, o parar.
  def retry_action(code, renewed:, attempt:)
    return :renew if code == 401 && !renewed
    return :wait if RETRIABLE.include?(code) && attempt < BACKOFF.size

    :stop
  end

  def request(verb, path, body:, token:)
    uri  = URI.parse("#{@config['base_url'].to_s.chomp('/')}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30

    req = verb.new(uri.request_uri)
    req['Authorization'] = "Bearer #{token}" if token.present?
    if body
      req['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    http.request(req)
  end

  def parse_answer(response)
    data = JSON.parse(response.body)
    # `sources` viene vacio —nunca null— en los tres 200 que no son respuesta, y
    # source_url es cadena vacia cuando el documento no tiene URL publica: una fuente
    # sin URL no debe producir un enlace roto.
    sources = Array(data['sources']).filter_map do |s|
      title = s['title'].to_s.strip
      next if title.blank?

      { title: title, url: s['source_url'].to_s.strip }
    end

    Result.new(answer: data['answer'].to_s.strip, sources: sources, message_id: data['message_id'])
  rescue JSON::ParserError => e
    Rails.logger.error "[CONTPAQi] ❌ Respuesta ilegible: #{e.message}"
    Result.new(error: :bad_response)
  end

  # El servicio devuelve el error en dos formas distintas segun quien lo emita: el
  # gateway usa `message`, la validacion del servicio usa `detail`.
  def log_failure(path, response)
    body   = JSON.parse(response.body) rescue nil # rubocop:disable Style/RescueModifier
    detail = body.is_a?(Hash) ? (body['message'] || body['detail']) : nil
    Rails.logger.error "[CONTPAQi] ❌ #{path} → #{response.code}: #{detail.to_s.truncate(200)}"
  end
end
