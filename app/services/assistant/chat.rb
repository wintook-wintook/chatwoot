# frozen_string_literal: true

# Asistente (Dali) — un turno de conversación. Manda al modelo (OpenAI, llamadas a
# funciones) las reglas, lo que el usuario está viendo, los últimos mensajes y lo que
# acaba de escribir; ejecuta las funciones de lectura y junta las propuestas (que
# esperan «Confirmar»). Guarda el turno en el AssistantThread.
#
# Uso: Assistant::Chat.new(thread:, grant:, zone:, context:).reply('agéndame…')
#   → el mensaje del asistente: { 'content', 'proposals' => [...], 'navigate' => ruta,
#       'cards' => [...] (datos de ventas), 'suggestions' => [...] (preguntas para seguir) }
# Modelo: el general de la cuenta; al explicar cifras de ventas, el de análisis
# (Assistant::Settings.model_for).
class Assistant::Chat < Cases::Ai::BaseService
  HISTORY = 12
  MAX_ROUNDS = 5
  MAX_TOKENS = 700
  ANALYSIS_TOKENS = 1100
  MAX_CARDS = 3
  MAX_SUGGESTIONS = 3

  def initialize(thread:, grant:, zone:, context: {})
    super(account: thread.account)
    @thread = thread
    @user = thread.user
    @zone = zone
    @context = context.to_h.stringify_keys
    @tools = Assistant::Tools.new(account: @account, user: @user, grant: grant, zone: zone)
    @capabilities = Assistant::Capabilities.for(grant)
  end

  def reply(text)
    history = history_messages
    start_turn(text)
    proposals = []
    navigate = nil
    cards = []
    suggestions = []
    content = run([{ role: 'system', content: system_prompt }, *history, { role: 'user', content: text.to_s }]) do |outcome|
      proposals << outcome[:proposal] if outcome[:proposal]
      navigate ||= outcome[:navigate]
      cards << outcome[:card] if outcome[:card]
      suggestions.concat(Array(outcome[:suggestions]))
    end
    @thread.add_message(role: 'assistant', content: content.presence || fallback(proposals),
                        proposals: proposals, navigate: navigate, cards: cards.first(MAX_CARDS),
                        suggestions: suggestions.uniq.first(MAX_SUGGESTIONS))
  end

  private

  # Guarda lo que escribió y se lo pasa a las funciones (las guías anotan la pregunta).
  def start_turn(text)
    @thread.add_message(role: 'user', content: text.to_s.strip, context: @context.slice('page', 'label'))
    @tools.turn = { question: text.to_s.strip, page: @context['page'] }
  end

  def run(messages)
    MAX_ROUNDS.times do
      message = complete(messages)
      return I18n.t('assistant.unavailable') unless message

      calls = message['tool_calls']
      return message['content'] if calls.blank?

      messages << message.slice('role', 'content', 'tool_calls')
      calls.each do |call|
        outcome = @tools.call(call.dig('function', 'name'), parse_args(call.dig('function', 'arguments')))
        @analysis ||= outcome[:analysis]
        yield outcome
        messages << { role: 'tool', tool_call_id: call['id'], content: outcome[:result].to_json }
      end
    end
    nil
  end

  def complete(messages)
    key = api_key
    return nil if key.blank?

    body = { model: model, messages: messages, tools: Assistant::Tools.definitions, tool_choice: 'auto',
             temperature: 0.2, max_tokens: @analysis ? ANALYSIS_TOKENS : MAX_TOKENS }
    raw = post_raw(key, body)
    raw&.dig('choices', 0, 'message')
  end

  # Una vez que llegaron cifras de ventas, las explica el modelo de análisis.
  def model
    Assistant::Settings.model_for(@account, @analysis ? :analysis : :general)
  end

  def post_raw(key, body)
    response = http_client.request(build_request(key, body))
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    Rails.logger.error("[Assistant] OpenAI HTTP #{response.code}: #{response.body.to_s[0, 300]}")
    nil
  rescue StandardError => e
    Rails.logger.error("[Assistant] OpenAI error: #{e.message}")
    nil
  end

  def http_client
    require 'net/http'
    uri = URI(API_URL)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
    end
  end

  def build_request(key, body)
    Net::HTTP::Post.new(URI(API_URL)).tap do |request|
      request['Authorization'] = "Bearer #{key}"
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
    end
  end

  def parse_args(json)
    JSON.parse(json.to_s)
  rescue JSON::ParserError
    {}
  end

  # Lo dicho antes, en texto: lo que se propuso y en qué quedó va entre corchetes.
  def history_messages
    @thread.messages.last(HISTORY).map do |m|
      notes = Array(m['proposals']).map { |p| "[Propuse #{p['type']}: #{p['labels'].to_h.values.compact.join(', ')} — #{p['status']}]" }
      { role: m['role'], content: [m['content'], *notes].compact_blank.join("\n") }
    end
  end

  def fallback(proposals)
    proposals.any? ? I18n.t('assistant.review_proposal') : I18n.t('assistant.unavailable')
  end

  def system_prompt
    now = Time.current.in_time_zone(@zone)
    <<~PROMPT
      Eres #{Assistant::Settings.name_for(@account)}, el asistente de #{@user.name} en Kontrolya (CRM: casos, oportunidades,
      contactos, organizaciones, conversaciones con clientes, tareas y agenda). Responde en español, breve y claro.

      Ahora: #{long_date(now)} (zona #{@zone.tzinfo.name}). Próximos días: #{next_days(now)}.
      #{screen_context}

      Reglas:
      - Para saber algo, usa las funciones de lectura (search, get_case, get_contact, my_agenda). No inventes datos.
      - Si te piden HACER algo (nota, tarea, agendar, programar mensaje), usa la función propose_* correspondiente.
        Eso NO lo hace: queda una tarjeta que el usuario confirma. Nunca digas que ya quedó hecho; di que lo revise y confirme.
        Cuando ya sepas qué proponer, LLAMA la función en ese mismo turno: nunca respondas «voy a proponer…» sin llamarla.
      - Al cliente solo con tarjeta (propose_reply, _draft, _scheduled_message, _send_quote). «¿Quién me escribió?»: my_conversations.
        Contestar («dile que…»): read_conversation y YA propose_reply, redactado corto y natural; sin can_reply, una plantilla.
      - Si no está claro de quién se habla, busca (search) con sus palabras exactas; si hay varios posibles, pregunta cuál.
      - Fechas y horas: interpreta «mañana», «el jueves», etc. con la fecha de ahora y escríbelas en hora local YYYY-MM-DDTHH:MM.
        Si no dicen hora para una cita, pregunta. Para una tarea sin hora, usa 09:00 si te dieron día.
      - «Esto», «este caso», «este cliente» es lo que el usuario está viendo (abajo). Abrir o ir a una pantalla: open_page.
      - «Dale seguimiento», «que el agente le escriba hasta que…», «delégalo»: usa propose_follow_up (#{AiFollowUp::DISPLAY_NAME},
        no se elige agente) con un objetivo concreto (y frecuencia/intentos si los dijeron). Si falta el objetivo, pregúntalo.
        Solo si el usuario nombra un agente del módulo de Agentes IA (p. ej. «con el agente Cobranza»): list_agents y propose_delegate.
        Si no hay conversación del cliente, dilo.
      - «¿Cómo va el seguimiento?»: tracking_status. Pausar, reanudar o cancelar: propose_follow_up_action (#{AiFollowUp::DISPLAY_NAME}) o propose_tracking_action (agente).
      - Casos: para crear usa list_case_types y propose_create_case (busca antes al contacto; si no existe, propone crearlo).
        Para mover de etapa, ganar/perder o posponer usa case_options primero (etapas y motivos) y luego la propuesta.
        Si el usuario ya dijo el resultado («la perdimos», «la ganamos»), propón directo (propose_outcome) con el motivo
        que mejor encaje con lo que dijo; no preguntes si quiere proceder: la tarjeta ya pide confirmar.
      - «Se comprometió a…», «prometió cerrar el…»: propose_update_opportunity con committed=true y expected_close_at.
      - Cotizar: search (cliente) y search_catalog (cada producto, con su precio salvo que diga otro); lo que no esté es partida
        libre y sin precio lo preguntas. Con eso llama YA propose_create_quote (no preguntes si procede ni calcules totales: la
        tarjeta los muestra y pide confirmar). Creada, «¿Se la mando?» → propose_send_quote. Ver: list_quotes.
      - «¿Dónde aparece…?», «búscame todo lo de…»: search y resume por grupo (contactos, organizaciones, casos) con totales;
        di en qué campo apareció si viene `match` («en la descripción de OPB-00012»). Si hay más, sugiere la lupa de arriba.
      - Al usuario nómbrale los registros por su folio o nombre (OPB-00003, «Mario Pérez»), nunca por su id interno.
      - No hagas acciones masivas (a muchos clientes a la vez): di que eso todavía no lo puedes hacer.

      Cómo se usa la plataforma («¿cómo creo…?», «¿dónde veo…?», «¿para qué sirve…?», «¿por qué no me deja…?»):
      - Primero search_guides con las palabras del usuario y luego read_guide de la que encaje. Contesta SOLO con lo que
        dice la guía: nunca inventes menús, botones, pantallas ni pasos. Si es para hacerlo tú (p. ej. «crea la tarea»),
        no hace falta guía: usa la función de propuesta.
      - Responde con pasos numerados cortos (máximo 6) usando los nombres del menú tal como vienen («Clientes › Contratos»).
        Si trae pantalla (pages), ofrece abrirla (open_page si dice que sí); si trae `url`, al final da ese enlace.
      - Si no hay guía, o la guía no trae la respuesta: llama report_gap (si leíste una guía) y di «eso todavía no lo tengo
        documentado; ya quedó anotado para agregarlo». Puedes sugerir a quién preguntarle (su administrador).
      - Si la guía dice que es de otra área o rol y el usuario no la ve, dile que eso lo hace quien tenga ese permiso.

      Tu alcance con ESTE usuario (según sus permisos). Si pregunta qué puedes hacer, en qué le ayudas, quién eres o cómo
      se usa, contesta con estas categorías en viñetas cortas y un ejemplo de cada una; no ofrezcas nada fuera de esta lista:
      #{@capabilities[:lines].map { |line| "  • #{line}" }.join("\n")}

      #{Assistant::PromptRules::SALES}

      #{Assistant::PromptRules::FIELD}
    PROMPT
  end

  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  # «lunes 02 de noviembre de 2026, 14:30» (sin depender de las traducciones de Rails).
  # «martes 10, miércoles 11, …»: para que «el viernes» no se calcule mal.
  def next_days(now)
    (1..7).map { |i| now + i.days }.map { |day| "#{DAYS[day.wday]} #{day.day} (#{day.to_date.iso8601})" }.join(', ')
  end

  def long_date(time)
    "#{DAYS[time.wday]} #{time.strftime('%d')} de #{MONTHS[time.month - 1]} de #{time.year}, #{time.strftime('%H:%M')}"
  end

  def screen_context
    parts = []
    parts << "El usuario está viendo el caso con id #{@context['case_id']}." if @context['case_id'].present?
    parts << "El usuario está viendo el contacto con id #{@context['contact_id']}." if @context['contact_id'].present?
    parts << "El usuario está viendo la organización con id #{@context['organization_id']}." if @context['organization_id'].present?
    parts << "El usuario está viendo la conversación número #{@context['conversation_id']}." if @context['conversation_id'].present?
    parts << "Pantalla: #{@context['page']}." if @context['page'].present?
    parts.any? ? parts.join(' ') : 'El usuario no está viendo un registro en particular.'
  end
end
