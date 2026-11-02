# frozen_string_literal: true

# Asistente (Dali) — un turno de conversación. Manda al modelo (OpenAI, llamadas a
# funciones) las reglas, lo que el usuario está viendo, los últimos mensajes y lo que
# acaba de escribir; ejecuta las funciones de lectura y junta las propuestas (que
# esperan «Confirmar»). Guarda el turno en el AssistantThread.
#
# Uso: Assistant::Chat.new(thread:, grant:, zone:, context:).reply('agéndame…')
#   → el mensaje del asistente: { 'content', 'proposals' => [...], 'navigate' => ruta }
class Assistant::Chat < Cases::Ai::BaseService
  HISTORY = 12
  MAX_ROUNDS = 5
  MAX_TOKENS = 700

  def initialize(thread:, grant:, zone:, context: {})
    super(account: thread.account)
    @thread = thread
    @user = thread.user
    @zone = zone
    @context = context.to_h.stringify_keys
    @tools = Assistant::Tools.new(account: @account, user: @user, grant: grant, zone: zone)
  end

  def reply(text)
    history = history_messages
    @thread.add_message(role: 'user', content: text.to_s.strip, context: @context.slice('page', 'label'))
    proposals = []
    navigate = nil
    content = run([{ role: 'system', content: system_prompt }, *history, { role: 'user', content: text.to_s }]) do |outcome|
      proposals << outcome[:proposal] if outcome[:proposal]
      navigate ||= outcome[:navigate]
    end
    @thread.add_message(role: 'assistant', content: content.presence || fallback(proposals),
                        proposals: proposals, navigate: navigate)
  end

  private

  def run(messages)
    MAX_ROUNDS.times do
      message = complete(messages)
      return I18n.t('assistant.unavailable') unless message

      calls = message['tool_calls']
      return message['content'] if calls.blank?

      messages << message.slice('role', 'content', 'tool_calls')
      calls.each do |call|
        outcome = @tools.call(call.dig('function', 'name'), parse_args(call.dig('function', 'arguments')))
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
             temperature: 0.2, max_tokens: MAX_TOKENS }
    raw = post_raw(key, body)
    raw&.dig('choices', 0, 'message')
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

      Ahora: #{long_date(now)} (zona #{@zone.tzinfo.name}).
      #{screen_context}

      Reglas:
      - Para saber algo, usa las funciones de lectura (search, get_case, get_contact, my_agenda). No inventes datos.
      - Si te piden HACER algo (nota, tarea, agendar, programar mensaje), usa la función propose_* correspondiente.
        Eso NO lo hace: queda una tarjeta que el usuario confirma. Nunca digas que ya quedó hecho; di que lo revise y confirme.
        Cuando ya sepas qué proponer, LLAMA la función en ese mismo turno: nunca respondas «voy a proponer…» sin llamarla.
      - Nunca envías mensajes al cliente. Para escribirle: propose_draft (borrador) o propose_scheduled_message.
      - Si no está claro de quién se habla, busca (search). Si hay varios resultados posibles, pregunta cuál, sin proponer.
      - Fechas y horas: interpreta «mañana», «el jueves», etc. con la fecha de ahora y escríbelas en hora local YYYY-MM-DDTHH:MM.
        Si no dicen hora para una cita, pregunta. Para una tarea sin hora, usa 09:00 si te dieron día.
      - «Esto», «este caso», «este cliente» se refieren a lo que el usuario está viendo (abajo).
      - Si te piden abrir o ir a una pantalla, usa open_page.
      - «Dale seguimiento», «que el agente le escriba hasta que…», «delégalo»: es delegar a un agente IA. Primero list_agents;
        si hay uno que encaja, propose_delegate con un objetivo concreto (y frecuencia/intentos si los dijeron); si hay varios
        y no es claro, pregunta cuál. Si no hay conversación del cliente, dilo.
      - «¿Cómo va el seguimiento?»: tracking_status. Pausar, reanudar o cancelar: propose_tracking_action.
      - Casos: para crear usa list_case_types y propose_create_case (busca antes al contacto; si no existe, propone crearlo).
        Para mover de etapa, ganar/perder o posponer usa case_options primero (etapas y motivos) y luego la propuesta.
        Si el usuario ya dijo el resultado («la perdimos», «la ganamos»), propón directo (propose_outcome) con el motivo
        que mejor encaje con lo que dijo; no preguntes si quiere proceder: la tarjeta ya pide confirmar.
      - «Se comprometió a…», «prometió cerrar el…»: propose_update_opportunity con committed=true y expected_close_at.
      - Al buscar usa exactamente las palabras del usuario (search «Mario», no inventes apellidos).
      - Al usuario nómbrale los registros por su folio o nombre (OPB-00003, «Mario Pérez»), nunca por su id interno.
      - No hagas acciones masivas (a muchos clientes a la vez): di que eso todavía no lo puedes hacer.
    PROMPT
  end

  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  # «lunes 02 de noviembre de 2026, 14:30» (sin depender de las traducciones de Rails).
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
