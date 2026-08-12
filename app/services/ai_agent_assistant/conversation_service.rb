# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Servicio: AiAgentAssistant::ConversationService
# Descripción: Un turno del chat asistente.
#
# Hereda de Cases::Ai::BaseService por la capa de transporte: es el cliente de
# chat-completion que ya resuelve la API key desde el hook `openai` DE LA CUENTA
# (multi-tenant, sin caer a una variable global) y tolera fallos devolviendo nil.
# El namespace dice «Cases» por dónde nació, pero el código no tiene nada de
# tickets; duplicarlo habría sido la cuarta copia del mismo Net::HTTP del repo.
#
# Lo que este servicio agrega es todo lo que hace que el asistente no sea un
# ChatGPT más: el system prompt se arma contra el estado real de la cuenta, la
# respuesta se sanea contra el Registry (no puede proponer lo que no existe) y se
# valida con el linter antes de enseñarla (invariante 7 del Anexo A).
#
# No persiste NADA en el Agente IA. Solo mueve el borrador de la sesión.
# ================================================================================

class AiAgentAssistant::ConversationService < Cases::Ai::BaseService
  MAX_TOKENS = 1_200
  TEMPERATURE = 0.4

  # Campos cuyo valor es una lista; cualquier otra cosa que llegue se descarta.
  LIST_FIELDS = %w[tags whatsapp_templates calendar_integration_ids keyword_actions].freeze
  INTEGER_FIELDS = %w[inbox_id retry_interval_value calendar_event_duration].freeze

  def initialize(session)
    super(account: session.account)
    @session = session
  end

  # `message` en blanco = turno de apertura: el asistente abre la conversación.
  def call(message = nil)
    return unavailable_turn unless available?

    session.append_message('user', message) if message.present?
    turn = parse_turn(post(api_key, request_body))
    return failed_turn if turn.nil?

    record(turn)
  end

  private

  attr_reader :session, :account

  def request_body
    {
      model: model,
      messages: model_messages,
      temperature: TEMPERATURE,
      max_tokens: MAX_TOKENS,
      response_format: { type: 'json_object' }
    }
  end

  def model_messages
    system = { role: 'system', content: AiAgentAssistant::SystemPrompt.for(session) }
    [system] + session.history_for_model
  end

  def parse_turn(content)
    return nil if content.blank?

    parsed = JSON.parse(content)
    return nil unless parsed.is_a?(Hash)

    {
      'reply' => parsed['reply'].to_s.strip,
      'proposals' => sanitize_proposals(parsed['proposals']),
      'next_step' => valid_step(parsed['next_step']),
      'done' => parsed['done'] == true
    }
  rescue JSON::ParserError => e
    Rails.logger.error("[AiAgentAssistant] respuesta no parseable: #{e.message} — #{content.to_s[0, 200]}")
    nil
  end

  # El modelo no puede inventar campos, ni proponer un inbox de otra cuenta, ni
  # repetir lo que el borrador ya tiene.
  def sanitize_proposals(raw)
    return [] unless raw.is_a?(Array)

    current = session.merged_draft
    raw.filter_map { |item| sanitize_proposal(item, current) }
       .uniq { |item| item['field'] }
  end

  def sanitize_proposal(item, current)
    return nil unless item.is_a?(Hash)

    field = item['field'].to_s
    return nil unless AiAgentAssistantSession::DRAFT_FIELDS.include?(field)

    value = coerce(field, item['value'])
    return nil if value.nil? || value == current[field]

    { 'field' => field, 'value' => value, 'rationale' => item['rationale'].to_s.strip.presence }
  end

  def coerce(field, value)
    return nil if value.nil?
    return coerce_list(field, value) if LIST_FIELDS.include?(field)
    return coerce_integer(field, value) if INTEGER_FIELDS.include?(field)

    value.to_s
  end

  def coerce_list(field, value)
    return nil unless value.is_a?(Array)
    return value.map(&:to_s) unless field == 'keyword_actions'

    value.filter_map { |entry| sanitize_keyword_action(entry) }
  end

  # Las acciones de palabra clave las valida el modelo TrackingTemplate al guardar;
  # una entrada mal formada tumbaría el guardado entero, así que se filtra aquí.
  def sanitize_keyword_action(entry)
    return nil unless entry.is_a?(Hash)

    keyword   = entry['keyword'].to_s.strip
    action    = entry['action'].to_s
    direction = entry['direction'].to_s
    return nil if keyword.blank?
    return nil unless ContactTrackings::KeywordActionService::VALID_ACTIONS.include?(action)
    return nil unless ContactTrackings::KeywordActionService::VALID_DIRECTIONS.include?(direction)

    { 'keyword' => keyword, 'action' => action, 'direction' => direction }
  end

  def coerce_integer(field, value)
    number = value.to_i
    return nil if number <= 0
    # Invariante 2: nunca proponer algo que en esta cuenta no existe.
    return nil if field == 'inbox_id' && !account.inboxes.exists?(id: number)

    number
  end

  def valid_step(value)
    key = value.to_s
    AiAgentAssistant::Interview.step(key) ? key : nil
  end

  def record(turn)
    session.append_message('assistant', turn['reply'])
    session.proposals = turn['proposals']
    session.step = turn['next_step'] if turn['next_step'].present?
    session.save!

    turn.merge('findings' => lint_proposal(turn['proposals']), 'step' => session.step)
  end

  # Invariante 7: el asistente valida su propia propuesta antes de enseñarla. Si lo
  # que propone rompe el agente, el usuario lo ve en el mismo turno.
  def lint_proposal(proposals)
    draft = session.merged_draft.merge(proposals.to_h { |p| [p['field'], p['value']] })
    # Instancia propia a propósito: asignarle los campos al `tracking_template` de la
    # sesión ensuciaría el borrador de los turnos siguientes, que se calcula desde él.
    template = account.tracking_templates.find_by(id: session.tracking_template_id) ||
               account.tracking_templates.new
    template.assign_attributes(draft.slice(*AiAgentAssistantSession::DRAFT_FIELDS))

    AiAgentAssistant::Linter.new(template, account: account).call
  rescue StandardError => e
    Rails.logger.warn("[AiAgentAssistant] no se pudo validar la propuesta: #{e.message}")
    []
  end

  def unavailable_turn
    { 'reply' => nil, 'proposals' => [], 'findings' => [], 'step' => session.step,
      'done' => false, 'error' => 'openai_not_configured' }
  end

  def failed_turn
    { 'reply' => nil, 'proposals' => [], 'findings' => [], 'step' => session.step,
      'done' => false, 'error' => 'model_unavailable' }
  end
end
