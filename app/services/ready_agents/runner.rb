# frozen_string_literal: true

# Agentes listos — un turno: el cliente escribió y el agente contesta.
#
#   ReadyAgents::Runner.new(agent, session: session).call            # en la conversación real
#   ReadyAgents::Runner.new(agent, history: [...]).test               # chat de prueba: no guarda ni manda nada
#
# Mismo motor que el Seguimiento IA (AiFollowUps::Runner): un modelo con herramientas que lee
# toda la plática. Lo que contesta al final es el mensaje para el cliente. Las decisiones
# (calificado, descartar, pasar a una persona) las aplica ReadyAgents::Outcomes después de
# mandar la despedida. Si una persona le escribió al cliente, el agente se hace a un lado.
class ReadyAgents::Runner < Cases::Ai::BaseService
  MAX_ROUNDS = 6
  MAX_TOKENS = 600
  NO_MESSAGE = '[SIN_MENSAJE]'

  attr_reader :used_tools

  def initialize(agent, session: nil, history: nil)
    super(account: agent.account)
    @agent = agent
    @session = session
    @conversation = session&.conversation
    @test_history = history
    @answers = session&.answers.to_h.dup || {}
    @search = AiFollowUps::KnowledgeSearch.new(account: @account)
    @used_tools = []
    @decision = nil
  end

  # with_lock recarga la sesión: dos turnos nunca corren a la vez en la misma conversación.
  def call
    @session.with_lock { turn if @session.active? }
  end

  # Chat de prueba: { reply:, tools:, decision:, answers: } sin tocar nada.
  def test
    return { error: 'La cuenta no tiene OpenAI configurado.' } if api_key.blank?

    prompt = ReadyAgents::Prompt.new(@agent, test_conversation, answers: @answers)
    content = run([{ role: 'system', content: prompt.system }, *@test_history, { role: 'system', content: TURN }])
    { reply: clean(content), tools: @used_tools, decision: @decision, answers: @answers, temperature: @temperature }
  end

  TURN = 'El cliente acaba de escribir (último mensaje). Contesta y sigue tu trabajo.'

  private

  def turn
    return pause_for_human! if human_stepped_in?
    return blocked! unless @conversation.can_reply?
    return fail_soft('La cuenta no tiene OpenAI configurado.') if api_key.blank?

    prompt = ReadyAgents::Prompt.new(@agent, @conversation, answers: @answers)
    content = run([{ role: 'system', content: prompt.system }, *prompt.history, { role: 'system', content: TURN }])
    return fail_soft('El modelo no respondió.') if content.nil?

    deliver(clean(content))
    @session.answers = @answers
    @session.last_error = nil
    @session.save!
    outcomes = ReadyAgents::Outcomes.new(@session, sender: sender)
    outcomes.appointment_booked if @booked
    outcomes.apply(*@decision) if @decision
  end

  # Una persona le escribió al cliente después del último mensaje del agente.
  def human_stepped_in?
    last_agent = @session.messages.maximum(:created_at) || @session.created_at
    @conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                 .where('created_at > ?', last_agent)
                 .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end

  def blocked!
    @session.add_log(:blocked, 'Fuera de la ventana para contestar.')
    @session.save!
  end

  def pause_for_human!
    @session.add_log(:paused, 'Una persona le escribió al cliente: el agente se hizo a un lado.')
    @session.update!(status: 'paused')
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

  def tools = ReadyAgents::ToolDefinitions.for(@agent)

  def parse_args(json)
    JSON.parse(json.to_s)
  rescue JSON::ParserError
    {}
  end

  # --- herramientas -------------------------------------------------------------------
  def tool(name, args)
    @used_tools << { name: name, args: args }
    return decide(name, args) if ReadyAgents::ToolDefinitions::DECISIONS.key?(name)

    case name
    when 'buscar_respuesta_predefinida' then @search.canned(args['pregunta'])
    when 'buscar_en_catalogo' then ReadyAgents::ToolDefinitions.catalog_search(@agent, args['consulta'])
    when 'guardar_respuesta' then save_answer(args)
    when 'actualizar_contacto' then update_contact(args)
    when 'ver_horarios', 'agendar_cita', 'mover_cita', 'cancelar_cita' then appointment(name, args)
    else { error: "herramienta desconocida: #{name}" }
    end
  end

  # Citas: en la conversación real se agendan; en el chat de prueba solo se leen los horarios.
  def appointment(name, args)
    return { error: 'Este agente no agenda citas.' } unless ReadyAgents::Appointments.available?(@agent)

    result = ReadyAgents::Appointments.new(@agent, session: @session).tool(name, args)
    @booked = true if name == 'agendar_cita' && result[:ok] && @session
    # Sin acceso al calendario: pasa a una persona (la nota interna dice de quién reconectar).
    if result[:sin_agenda]
      @decision = ['pasar_a_humano', result[:motivo]]
      @calendar_handoff = true
    end
    result.except(:motivo)
  rescue StandardError => e
    Rails.logger.error("[ReadyAgents::Runner] cita: #{e.class}: #{e.message}")
    { error: 'No se pudo con el calendario en este momento: dile que alguien del equipo le confirma.' }
  end

  # Si ya se pasó a una persona por no poder leer el calendario, eso se queda (con su motivo).
  # Calificarlo pide antes los datos obligatorios del contacto (los que marcó la empresa).
  def decide(name, args)
    missing = ReadyAgents::Qualification.missing_contact(@agent, @conversation&.contact, @noted_contact.to_h)
    if name == 'prospecto_calificado' && missing.any?
      return { error: "Antes de calificarlo pídele su #{missing.join(' y ')} (con naturalidad) y guárdalo con actualizar_contacto." }
    end

    text = args[ReadyAgents::ToolDefinitions::DECISIONS[name]].to_s
    temperature = args['temperatura'].to_s if ReadyAgents::Qualification::TEMPERATURES.include?(args['temperatura'].to_s)
    @decision = [name, text, temperature].compact unless @calendar_handoff
    @temperature = temperature
    { ok: true, nota: 'Listo. Ahora escribe solo el mensaje final para el cliente.' }
  end

  def save_answer(args)
    return { error: 'Falta la pregunta o la respuesta.' } if args['pregunta'].blank? || args['respuesta'].blank?

    @answers[args['pregunta'].to_s.first(80)] = args['respuesta'].to_s.first(300)
    { ok: true }
  end

  # Nombre, correo, empresa y ciudad; en el chat de prueba solo se anota.
  def update_contact(args)
    data = ReadyAgents::Qualification.contact_data(args)
    (@noted_contact ||= {}).merge!(data)
    return { ok: true } if data.empty? || @session.nil?

    contact = @conversation.contact
    attrs = contact.additional_attributes.to_h.merge({ 'company_name' => data['empresa'], 'city' => data['ciudad'] }.compact)
    contact.update(name: data['nombre'] || contact.name, email: data['correo'] || contact.email, additional_attributes: attrs)
    { ok: true }
  end

  # --- después ------------------------------------------------------------------------
  def clean(content)
    text = content.to_s.strip
    text.include?(NO_MESSAGE) ? '' : text
  end

  def deliver(text)
    return if text.blank?

    message = Messages::MessageBuilder.new(sender, @conversation,
                                           { content: text, private: false, ai_agent: { name: @agent.name } }).perform
    message.content_attributes[:ready_agent_session_id] = @session.id
    message.content_attributes[:sentiment_auto_reply] = true
    message.save!
    @session.add_log(:sent, text)
  end

  # Falla del modelo o de la red: se anota; el siguiente mensaje del cliente lo vuelve a intentar.
  def fail_soft(text)
    @session.update!(last_error: [text, @error].compact.join(' — ').first(500))
  end

  def sender = ReadyAgents::ClientHandoff.sender(@agent)

  def test_conversation
    Struct.new(:inbox, :contact, :messages).new(@account.inboxes.find_by(id: @agent.inbox_ids.first), nil, nil)
  end
end
