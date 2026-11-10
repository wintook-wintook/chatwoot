# frozen_string_literal: true

# Seguimiento IA — un turno del agente.
#
#   AiFollowUps::Runner.new(follow_up, trigger: :reply | :scheduled | :start).call
#
# Le manda al modelo el objetivo, las indicaciones, los datos del cliente y del caso y
# la conversación como mensajes reales; el modelo usa herramientas (buscar en las
# respuestas predefinidas, programar el siguiente contacto, marcar cumplido, cerrar, pasar a humano)
# tantas veces como necesite y lo que contesta al final es el mensaje para el cliente.
# Siempre deja anotado lo que pasó (log) y, al terminar, avisa a quien delegó.
#
# Ventana de WhatsApp cerrada: el turno es de plantilla. El modelo ve las plantillas aprobadas
# de la bandeja (o solo la que fijó quien delegó), elige la más conveniente, llena sus
# variables y la manda con enviar_plantilla (AiFollowUps::TemplateTurn). Cuenta como intento.
class AiFollowUps::Runner < Cases::Ai::BaseService # rubocop:disable Metrics/ClassLength
  MAX_ROUNDS = 6
  MAX_TOKENS = 700
  NO_MESSAGE = '[SIN_MENSAJE]'
  BLOCKED = 'No se le puede escribir al cliente: el canal está fuera de su ventana de respuesta (WhatsApp 24 h). ' \
            'Escríbele con una plantilla o espera a que conteste.'
  NO_TEMPLATES = 'La ventana de 24 h de WhatsApp está cerrada y la bandeja no tiene plantillas aprobadas que el agente ' \
                 'pueda usar (sin archivo en el encabezado ni variables en botones).'

  def initialize(follow_up, trigger:)
    super(account: follow_up.account)
    @follow_up = follow_up
    @trigger = trigger.to_sym
    @conversation = follow_up.conversation
    @search = AiFollowUps::KnowledgeSearch.new(account: @account)
    @canned_used = []
    @decision = nil
    @scheduled_at = nil
    @template_turn = nil
  end

  # with_lock recarga la fila: dos turnos nunca corren a la vez sobre el mismo seguimiento.
  # (Sin `return` dentro del bloque: en Rails 7 salir así de una transacción la deshace.)
  def call
    ran = false
    @follow_up.with_lock do
      ran = runnable?
      turn if ran
    end
    notifier = AiFollowUps::Notifier.new(@follow_up)
    return unless ran

    notifier.finished if AiFollowUp::FINISHED.include?(@follow_up.status)
    notifier.paused_for_human if @follow_up.status == 'paused'
  end

  private

  # Activo y, si no es respuesta al cliente, que ya le toque (otro turno pudo moverle la fecha).
  def runnable?
    return false unless @follow_up.status == 'active'
    return true if @trigger == :reply
    return false if @follow_up.next_run_at&.future?

    @trigger = :start unless agent_messages.exists?
    true
  end

  def turn
    return if stop_before_running?

    messages = initial_messages
    content = run(messages)
    return after_template_turn(content) if @template_turn
    return fail_soft('El modelo no respondió.') if content.nil?

    content = rewrite_leak(messages, content)
    return fail_soft('La respuesta copiaba instrucciones internas de una respuesta predefinida.') if content.nil?

    deliver(content)
    apply_decision
    @follow_up.save!
  end

  # Turno de plantilla: lo que el modelo escriba al final no se manda (la ventana está cerrada).
  def after_template_turn(content)
    if @template_turn.sent?
      @follow_up.attempts += 1
      apply_decision
      return @follow_up.save!
    end
    return finish!('blocked', "#{BLOCKED} #{@template_turn.refusal}") if @template_turn.refusal
    return fail_soft('El modelo no respondió.') if content.nil?

    finish!('blocked', "#{BLOCKED} El agente no eligió ninguna plantilla.")
  end

  # --- antes de correr ----------------------------------------------------------------
  def stop_before_running?
    return finish!('no_response', "Sin respuesta después de #{@follow_up.attempts} intentos.") if out_of_attempts?
    return pause_for_human! if human_stepped_in?
    return closed_window! unless @conversation.can_reply?
    return fail_soft('La cuenta no tiene OpenAI configurado.') if api_key.blank?

    false
  end

  def out_of_attempts?
    @trigger != :reply && @follow_up.attempts >= @follow_up.max_attempts
  end

  # Una persona le escribió al cliente después del último mensaje del agente → el agente se hace a un lado.
  def human_stepped_in?
    last_agent = agent_messages.maximum(:created_at) || @follow_up.created_at
    @conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                 .where('created_at > ?', last_agent)
                 .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_follow_up_id')}, '') = ''")
                 .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end

  # Ventana cerrada: con plantillas usables el turno sigue, pero de plantilla; sin ellas, se detiene.
  def closed_window!
    turn = AiFollowUps::TemplateTurn.new(@follow_up, sender: sender)
    return finish!('blocked', turn.unavailable_reason) unless turn.possible?

    @template_turn = turn
    false
  end

  def pause_for_human!
    @follow_up.add_log(:paused, 'Una persona le escribió al cliente: el agente se hizo a un lado.')
    @follow_up.update!(status: 'paused')
    true
  end

  # --- el modelo ----------------------------------------------------------------------
  def run(messages)
    MAX_ROUNDS.times do
      message = complete(messages)
      return nil unless message

      calls = message['tool_calls']
      return message['content'].to_s if calls.blank?

      messages << message.slice('role', 'content', 'tool_calls')
      calls.each do |call|
        result = tool(call.dig('function', 'name'), parse_args(call.dig('function', 'arguments')))
        messages << { role: 'tool', tool_call_id: call['id'], content: result.to_json }
      end
    end
    nil
  end

  def complete(messages)
    body = { model: Assistant::Settings.model_for(@account), messages: messages, temperature: 0.4,
             max_tokens: MAX_TOKENS, tools: tools, tool_choice: 'auto' }
    response = http.request(request(body))
    return JSON.parse(response.body).dig('choices', 0, 'message') if response.is_a?(Net::HTTPSuccess)

    @error = "OpenAI HTTP #{response.code}: #{response.body.to_s[0, 200]}"
    Rails.logger.error("[AiFollowUp] #{@error}")
    nil
  rescue StandardError => e
    @error = e.message
    Rails.logger.error("[AiFollowUp] #{e.message}")
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

  def tools
    return AiFollowUps::ToolDefinitions::TEMPLATE if @template_turn
    return AiFollowUps::ToolDefinitions::ALL if @search.canned_available?

    AiFollowUps::ToolDefinitions::ALL.reject { |t| t.dig(:function, :name) == 'buscar_respuesta_predefinida' }
  end

  def parse_args(json)
    JSON.parse(json.to_s)
  rescue JSON::ParserError
    {}
  end

  # --- herramientas -------------------------------------------------------------------
  DECISIONS = { 'marcar_cumplido' => %w[done resumen], 'cerrar_sin_exito' => %w[failed motivo],
                'pasar_a_humano' => %w[handed_off motivo] }.freeze

  def tool(name, args)
    return decide(DECISIONS[name][0], args[DECISIONS[name][1]]) if DECISIONS.key?(name)

    case name
    when 'buscar_respuesta_predefinida' then canned_search(args['pregunta'])
    when 'programar_siguiente_contacto' then schedule(args)
    when 'enviar_plantilla', 'ninguna_plantilla' then template_tool(name, args)
    else { error: "herramienta desconocida: #{name}" }
    end
  end

  def template_tool(name, args)
    return { error: 'La ventana está abierta: escribe el mensaje normal.' } unless @template_turn
    return @template_turn.refuse(args['motivo']) if name == 'ninguna_plantilla'

    @template_turn.send_template(args)
  end

  def canned_search(question)
    @follow_up.add_log(:canned, question)
    @search.canned(question).tap do |found|
      @canned_used |= Array(found[:results]).filter_map { |r| r[:codigo] if r[:instrucciones_internas] }
    end
  end

  def schedule(args)
    at = @follow_up.zone.parse(args['cuando'].to_s)
    return { error: 'Fecha no válida; usa YYYY-MM-DDTHH:MM.' } if at.nil?
    return { error: 'Esa fecha ya pasó.' } if at < Time.current

    @scheduled_at = at
    @follow_up.add_log(:scheduled, "#{I18n.l(at, format: :short)} — #{args['motivo']}")
    { ok: true, siguiente_contacto: at.iso8601 }
  end

  def decide(status, text)
    @decision = [status, text.to_s]
    { ok: true, nota: 'Listo. Ahora escribe solo el mensaje final para el cliente (o [SIN_MENSAJE]).' }
  end

  # --- después ------------------------------------------------------------------------
  def deliver(content)
    text = content.to_s.strip
    return if text.blank? || text.include?(NO_MESSAGE)

    message = Messages::MessageBuilder.new(sender, @conversation,
                                           { content: text, private: false, ai_agent: { name: nil } }).perform
    message.content_attributes[:ai_follow_up_id] = @follow_up.id
    message.content_attributes[:sentiment_auto_reply] = true
    message.save!
    @follow_up.add_log(:sent, text)
    @follow_up.attempts = @trigger == :reply ? 0 : @follow_up.attempts + 1
  end

  def apply_decision
    @follow_up.last_error = nil
    if @decision
      status, text = @decision
      @follow_up.assign_attributes(status: status, outcome: text, finished_at: Time.current, next_run_at: nil)
      @follow_up.add_log(status, text)
    else
      @follow_up.next_run_at = @scheduled_at || (Time.current + @follow_up.interval)
    end
  end

  # Si la respuesta copia las instrucciones internas de una predefinida (misma regla que el
  # motor de siempre: KnowledgeBase::CannedPrompt#leaks?), se le pide reescribirla una vez.
  def rewrite_leak(messages, content)
    return content unless leaks?(content)

    @follow_up.add_log(:leak, 'La respuesta copiaba instrucciones internas: se reescribió.')
    messages << { role: 'assistant', content: content }
    messages << { role: 'system', content: 'Tu respuesta copia instrucciones internas. Reescríbela solo con lo que le ' \
                                           'dirías al cliente, sin mencionar instrucciones.' }
    retry_content = run(messages)
    retry_content && !leaks?(retry_content) ? retry_content : nil
  end

  def leaks?(content)
    return false if @canned_used.empty?

    @account.canned_responses.where(short_code: @canned_used).any? do |canned|
      item = Struct.new(:source_type, :source_id).new('canned_response', canned.id)
      KnowledgeBase::CannedPrompt.detect(@account, [item])&.leaks?(content)
    end
  end

  def finish!(status, text)
    @follow_up.add_log(status, text)
    @follow_up.update!(status: status, outcome: text, finished_at: Time.current, next_run_at: nil)
    true
  end

  # Falla del modelo o de la red: se reintenta en 15 minutos, sin gastar intento.
  def fail_soft(text)
    @follow_up.update!(last_error: [text, @error].compact.join(' — ').first(500), next_run_at: 15.minutes.from_now)
    true
  end

  def sender
    @follow_up.created_by || @account.users.first
  end

  def agent_messages
    @follow_up.messages.where(private: false)
  end

  # --- lo que ve el modelo ------------------------------------------------------------
  def initial_messages
    prompt = AiFollowUps::Prompt.new(@follow_up, canned: @search.canned_available?)
    turn = @template_turn ? @template_turn.instructions : prompt.turn(@trigger)
    [{ role: 'system', content: prompt.system }, *prompt.history, { role: 'system', content: turn }]
  end
end
