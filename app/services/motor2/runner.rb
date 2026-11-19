# frozen_string_literal: true

# Motor 2.0 — un turno del agente: el modelo lee la plática, usa las herramientas de sus
# habilidades las veces que necesite y lo que contesta al final es el mensaje para el cliente.
# No manda nada: regresa la respuesta, la decisión y la traza (Motor2::Reply / Motor2::Attempt
# la mandan; el chat de prueba solo la enseña).
#
#   Motor2::Runner.new(config, state:, conversation:, mode: :reply).call
#   Motor2::Runner.new(config, state:, history: [{ role: 'user', content: 'hola' }]).call   # prueba
#   → Motor2::Runner::Result(reply:, decision:, trace:, error:)
#
# Revisiones del código antes de soltar la respuesta (las que el 1.0 ya aprendió):
#   - respuesta vacía de OpenAI → se pide otra vez (e4fae498);
#   - copia instrucciones internas de una predefinida → se reescribe una vez;
#   - da un precio o porcentaje que no vio en ningún lado → se reescribe una vez;
#   - ligas que no vio → se quitan (KnowledgeBase::LinkGuard);
#   - con preguntas en secuencia (Calificar), si no termina con la pendiente → se pide una vez y,
#     si aun así no, se agrega tal cual.
class Motor2::Runner < Cases::Ai::BaseService
  include Motor2::QuestionGuard
  MAX_ROUNDS = 6
  MAX_TOKENS = 700
  NO_MESSAGE = '[SIN_MENSAJE]'
  MONEY = /(?:\$\s?\d[\d,.]*|\d[\d,.]*\s?(?:pesos|mxn|usd|dólares|%))/i

  Result = Struct.new(:reply, :decision, :trace, :error, :attachments, :after, keyword_init: true)
  MAX_FILES = 5

  attr_reader :config, :state, :trace, :conversation, :tracking, :canned_used, :seen, :noted_contact

  # opts: conversation:, tracking:, history: (chat de prueba), mode: :reply | :attempt, attempt: [n, total],
  #       welcome: (bienvenida combinada: va tal cual al inicio del mensaje; el modelo no vuelve a saludar)
  def initialize(config, state:, **opts)
    super(account: config.account)
    @config = config
    @state = state
    @conversation = opts[:conversation]
    @tracking = opts[:tracking]
    @test_history = opts[:history]
    @mode = opts[:mode] || :reply
    @attempt = opts[:attempt]
    @welcome = opts[:welcome].to_s.strip.presence
    @trace = Motor2::Trace.new
    @canned_used = []
    @seen = []
    @noted_contact = {} # lo que el cliente dio con actualizar_contacto en este turno (Calificar lo revisa)
    @decision = nil
    @attachments = []
    @after = []
  end

  def test? = !@test_history.nil?

  # Las habilidades llaman esto: la decisión se aplica después de mandar el mensaje.
  def decide(kind, text)
    @decision = [kind, text.to_s.strip.first(500)]
  end

  # Un archivo del agente que va con la respuesta (máximo 5; no se repite en el mismo mensaje).
  def attach(name)
    file = @config.template.ai_agent_attachments.where('LOWER(name) = ?', name.to_s.downcase).first
    return false unless file&.file&.attached?
    return true if @attachments.any? { |a| a[:id] == file.id }
    return false if @attachments.size >= MAX_FILES

    @attachments << { id: file.id, name: file.name, signed_id: file.file.blob.signed_id }
    @trace.event(:archivo, file.name)
    true
  end

  # Lo que va después de mandar el mensaje (archivos de la cita o del caso, reglas del caso).
  def after_send(&block)
    @after << block
  end

  def call
    return Result.new(error: 'La cuenta no tiene OpenAI configurado.', trace: @trace.to_h) if api_key.blank?

    @skills = Motor2::Skills.for(self)
    messages = initial_messages
    content = first_answer(messages)
    return Result.new(error: ['El modelo no respondió.', @error].compact.join(' — '), trace: @trace.to_h) if content.nil?

    Result.new(reply: with_welcome(review(messages, clean(content))), decision: @decision, trace: @trace.to_h,
               attachments: @attachments, after: @after)
  end

  private

  def initial_messages
    prompt = Motor2::Prompt.new(self, @skills)
    history = turn_history
    system = prompt.system
    @seen << system << history.pluck(:content).join("\n")
    turn = [prompt.turn_message(@mode, attempt: @attempt), welcome_note, *@skills.map(&:turn_note)].compact_blank.join("\n")
    [{ role: 'system', content: system }, *history, { role: 'system', content: turn }]
  end

  # La plática del turno; las habilidades deducen lo suyo (p. ej. qué pregunta acaba de contestar).
  def turn_history
    history = test? ? @test_history.map { |m| m.to_h.symbolize_keys.slice(:role, :content) } : Motor2::Prompt.history(@conversation)
    @skills.each { |skill| skill.prepare(history) }
    @last_customer = history.reverse.find { |m| m[:role].to_s == 'user' }&.dig(:content).to_s
    history
  end

  # --- el modelo ----------------------------------------------------------------------
  # Una respuesta vacía de OpenAI no deja al cliente sin contestar: se pide otra vez.
  def first_answer(messages)
    2.times do
      content = run(messages)
      return content if content
    end
    nil
  end

  def run(messages)
    MAX_ROUNDS.times do
      message = complete(messages)
      return nil unless message

      calls = message['tool_calls']
      return message['content'].to_s.presence if calls.blank?

      messages << message.slice('role', 'content', 'tool_calls')
      calls.each do |call|
        result = tool(call.dig('function', 'name'), parse_args(call.dig('function', 'arguments')))
        messages << { role: 'tool', tool_call_id: call['id'], content: result.to_json }
      end
    end
    nil
  end

  def complete(messages)
    body = { model: AiModels::AGENTS, messages: messages, temperature: 0.4,
             max_tokens: MAX_TOKENS, tools: tool_definitions, tool_choice: 'auto' }
    response = http.request(request(body))
    return JSON.parse(response.body).dig('choices', 0, 'message') if response.is_a?(Net::HTTPSuccess)

    @error = "OpenAI HTTP #{response.code}: #{response.body.to_s[0, 200]}"
    nil
  rescue StandardError => e
    @error = e.message
    nil
  end

  def http
    require 'net/http'
    uri = URI(API_URL)
    Net::HTTP.new(uri.host, uri.port).tap do |h|
      h.use_ssl = true
      h.read_timeout = READ_TIMEOUT
    end
  end

  def request(body)
    Net::HTTP::Post.new(URI(API_URL)).tap do |r|
      r['Authorization'] = "Bearer #{api_key}"
      r['Content-Type'] = 'application/json'
      r.body = body.to_json
    end
  end

  def tool_definitions = @skills.flat_map(&:tools)

  def parse_args(json)
    JSON.parse(json.to_s)
  rescue JSON::ParserError
    {}
  end

  def tool(name, args)
    skill = @skills.find { |s| s.handles?(name) }
    result = skill ? skill.call(name, args) : { error: "herramienta desconocida: #{name}" }
    @trace.tool(name, args, result)
    result
  rescue StandardError => e
    Rails.logger.error("[Motor2] #{name}: #{e.class}: #{e.message}")
    @trace.tool(name, args, { error: e.message })
    { error: 'No se pudo en este momento.' }
  end

  # --- revisiones ---------------------------------------------------------------------
  def clean(content)
    text = content.to_s.strip
    text.include?(NO_MESSAGE) ? '' : text
  end

  def review(messages, text)
    return text if text.blank?

    text = rewrite(messages, text, :leak) if leaks?(text)
    text = rewrite(messages, text, :unsourced) if text.present? && unsourced?(text)
    text = guard_turn(messages, text) if text.present?
    guard_links(text)
  end

  REWRITE = {
    leak: 'Tu respuesta copia instrucciones internas. Reescríbela solo con lo que le dirías al cliente.',
    unsourced: 'Tu respuesta da un precio, monto o porcentaje que no salió de buscar_en_fuentes ni de tus ' \
               'instrucciones. Búscalo con buscar_en_fuentes; si no sale, no lo des y ofrece pasarlo con una persona.'
  }.freeze

  def rewrite(messages, text, kind)
    @trace.event(:revision, kind)
    messages << { role: 'assistant', content: text } << { role: 'system', content: REWRITE[kind] }
    again = clean(run(messages))
    return again if again.present? && !(kind == :leak ? leaks?(again) : unsourced?(again))

    @trace.event(:revision, "#{kind}: no se pudo corregir, no se manda")
    ''
  end

  # Mismo criterio que el 1.0 (KnowledgeBase::CannedPrompt#leaks?).
  def leaks?(text)
    return false if @canned_used.empty?

    @account.canned_responses.where(short_code: @canned_used.uniq).any? do |canned|
      item = Struct.new(:source_type, :source_id).new('canned_response', canned.id)
      KnowledgeBase::CannedPrompt.detect(@account, [item])&.leaks?(text)
    end
  end

  # Un monto que no aparece en nada de lo que vio (instrucciones, fuentes, plática).
  def unsourced?(text)
    seen = digits(@seen.join("\n"))
    text.scan(MONEY).any? { |amount| seen.exclude?(amount.gsub(/\D/, '')) }
  end

  def digits(text) = text.scan(/\d[\d,.]*/).to_set { |n| n.gsub(/\D/, '') }

  def guard_links(text)
    kept, removed = KnowledgeBase::LinkGuard.call(text, @seen.join("\n"))
    @trace.event(:ligas_quitadas, removed.join(' ')) if removed.any?
    kept
  end
end
