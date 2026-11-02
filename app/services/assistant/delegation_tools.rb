# frozen_string_literal: true

# Asistente (Dali) — D3: delegar un seguimiento a un agente IA hablando.
#   • list_agents: los agentes de seguimiento (plantillas) que sirven para la
#     conversación del cliente;
#   • tracking_status: cómo van los seguimientos de un contacto o caso;
#   • propose_delegate: propone crear el seguimiento (se confirma con tarjeta);
#   • propose_tracking_action: propone pausar, reanudar o cancelar uno.
# Se incluye en Assistant::Tools (usa contacts/cases/find_conversation/local).
module Assistant::DelegationTools
  LIVE = %w[pending scheduled active paused].freeze
  ACTIONS = %w[pause resume cancel].freeze

  def tool_list_agents(args)
    conversation = delegation_conversation(args)
    templates = @account.tracking_templates.where(archived_at: nil)
    templates = templates.where(inbox_id: [nil, conversation.inbox_id]) if conversation
    { conversation: conversation && { id: conversation.display_id, inbox: conversation.inbox&.name },
      agents: templates.order(:name).limit(20).map { |t| agent_ref(t) } }
  rescue ArgumentError => e
    { error: e.message }
  end

  def tool_tracking_status(args)
    contact = delegation_contact(args)
    trackings = ContactTracking.where(account_id: @account.id).where(contact_id: contact.id).order(created_at: :desc).limit(5)
    { contact: contact.name, trackings: trackings.map { |t| tracking_ref(t) } }
  rescue ArgumentError => e
    { error: e.message }
  end

  def prepare_delegate(args)
    conversation = delegation_conversation(args)
    raise ArgumentError, 'Necesito una conversación del cliente para delegar el seguimiento.' unless conversation

    agent = agent_for(args['agent_id'], conversation)
    payload = delegate_payload(args, conversation, agent)
    [payload, { 'agent' => agent.name, 'conversation' => conversation_label(conversation), 'target' => delegate_target(args) }]
  end

  def prepare_tracking_action(args)
    raise ArgumentError, 'Acción no válida: pause, resume o cancel.' unless ACTIONS.include?(args['action'].to_s)

    tracking = visible_tracking(args['tracking_id'])
    [{ 'tracking_id' => tracking.id, 'action' => args['action'].to_s },
     { 'agent' => tracking.tracking_template&.name, 'target' => tracking.contact&.name, 'status' => tracking.status }]
  end

  def visible_tracking(id)
    tracking = ContactTracking.where(account_id: @account.id).find_by(id: id)
    raise ArgumentError, 'No encontré ese seguimiento.' unless tracking && contacts.exists?(tracking.contact_id)

    tracking
  end

  private

  # Contacto del caso o el contacto dado.
  def delegation_contact(args)
    return cases.find(args['case_id']).contact || raise(ArgumentError, 'El caso no tiene contacto.') if args['case_id'].present?
    raise ArgumentError, 'Dime de qué cliente.' if args['contact_id'].blank?

    contacts.find(args['contact_id'])
  end

  # La conversación dada; si no, la principal del caso; si no, la más reciente del contacto.
  def delegation_conversation(args)
    return find_conversation(args['conversation_id']) if args['conversation_id'].present?

    if args['case_id'].present?
      ticket = cases.find(args['case_id'])
      return ticket.conversation if ticket.conversation
    end
    return nil if args['case_id'].blank? && args['contact_id'].blank?

    contact = delegation_contact(args)
    @grant.conversations(@account.conversations).where(contact_id: contact.id).order(last_activity_at: :desc).first
  end

  def agent_for(id, conversation)
    agent = @account.tracking_templates.where(archived_at: nil).find_by(id: id)
    raise ArgumentError, 'Elige un agente de la lista (list_agents).' unless agent
    raise ArgumentError, "El agente #{agent.name} es de otra bandeja." if agent.inbox_id && agent.inbox_id != conversation.inbox_id

    agent
  end

  def delegate_payload(args, conversation, agent)
    starts = parse_local(args['starts_at']) || 5.minutes.from_now
    { 'agent_id' => agent.id, 'conversation_id' => conversation.display_id, 'case_id' => args['case_id'],
      'objective' => (args['objective'].presence || agent.objective).to_s.first(500),
      'instruction' => args['instruction'].to_s, 'starts_at' => [starts, 2.minutes.from_now].max.iso8601 }
      .merge(delegate_rhythm(args, agent))
  end

  def delegate_rhythm(args, agent)
    attempts = args['max_attempts'].present? ? args['max_attempts'].to_i.clamp(1, 10) : default_attempts(agent)
    { 'max_attempts' => attempts,
      'interval_value' => (args['interval_value'].presence || agent.retry_interval_value || 1).to_i,
      'interval_unit' => args['interval_unit'].presence_in(%w[minutes hours days]) || agent.retry_interval_unit || 'days' }
  end

  def default_attempts(agent)
    templates = Array(agent.whatsapp_templates).compact_blank
    templates.any? ? templates.size : 3
  end

  def delegate_target(args)
    return cases.find(args['case_id']).folio if args['case_id'].present?

    contacts.find_by(id: args['contact_id'])&.name
  end

  def agent_ref(template)
    { id: template.id, name: template.name, objective: template.objective.to_s.truncate(160),
      inbox_id: template.inbox_id, attempts: default_attempts(template),
      every: "#{template.retry_interval_value} #{template.retry_interval_unit}" }
  end

  def tracking_ref(tracking)
    { id: tracking.id, agent: tracking.tracking_template&.name, status: tracking.status, objective: tracking.objective,
      attempts: "#{tracking.attempt_count}/#{tracking.max_attempts}", next_at: local(tracking.scheduled_for),
      last_attempt_at: local(tracking.last_attempt_at), last_message: tracking.last_message_sent.to_s.truncate(200),
      outcome: tracking.outcome, last_intent: tracking.last_intent, live: LIVE.include?(tracking.status) }
  end
end
