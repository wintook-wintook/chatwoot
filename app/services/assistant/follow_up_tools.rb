# frozen_string_literal: true

# Asistente (Dali) — Seguimiento IA, el agente nuevo con herramientas:
#   • propose_follow_up: delegar el seguimiento del cliente (no se elige agente);
#   • propose_follow_up_action: pausarlo, reanudarlo o cancelarlo.
# tracking_status (DelegationTools) también los lista. Se incluye en Assistant::Tools.
module Assistant::FollowUpTools
  # Seguimiento IA — delegar al agente nuevo (no se elige agente).
  def prepare_follow_up(args)
    conversation = delegation_conversation(args)
    raise ArgumentError, 'Necesito una conversación del cliente para delegar el seguimiento.' unless conversation
    raise ArgumentError, 'Dime qué debe lograr el seguimiento.' if args['objective'].blank?

    payload = { 'conversation_id' => conversation.display_id, 'case_id' => args['case_id'],
                'objective' => args['objective'].to_s.first(1000), 'instruction' => args['instruction'].to_s,
                'starts_at' => parse_local(args['starts_at'])&.iso8601 }
              .merge(follow_up_rhythm(args), follow_up_template(conversation, args['template_name']))
    [payload, { 'agent' => AiFollowUp::DISPLAY_NAME, 'conversation' => conversation_label(conversation),
                'target' => delegate_target(args), 'template' => payload['template_name'] }.compact]
  end

  def prepare_follow_up_action(args)
    raise ArgumentError, 'Acción no válida: pause, resume o cancel.' unless ACTIONS.include?(args['action'].to_s)

    follow_up = visible_follow_up(args['follow_up_id'])
    [{ 'follow_up_id' => follow_up.id, 'action' => args['action'].to_s },
     { 'agent' => AiFollowUp::DISPLAY_NAME, 'target' => follow_up.contact&.name, 'status' => follow_up.status }]
  end

  def visible_follow_up(id)
    follow_up = AiFollowUp.where(account_id: @account.id).find_by(id: id)
    raise ArgumentError, 'No encontré ese seguimiento.' unless follow_up && find_conversation(follow_up.conversation.display_id)

    follow_up
  end

  private

  def follow_up_rhythm(args)
    { 'max_attempts' => (args['max_attempts'].presence || 3).to_i.clamp(1, 10),
      'interval_value' => [args['interval_value'].to_i, 1].max,
      'interval_unit' => args['interval_unit'].presence_in(AiFollowUp::UNITS) || 'days' }
  end

  # Plantilla fijada (si el usuario la nombró): tiene que existir y ser usable en la bandeja.
  def follow_up_template(conversation, name)
    return {} if name.blank?

    template = AiFollowUps::Templates.new(conversation).find(name)
    raise ArgumentError, "La plantilla «#{name}» no está aprobada en esa bandeja o no se puede usar." unless template

    { 'template_name' => template[:name], 'template_language' => template[:language] }
  end

  def follow_up_ref(follow_up)
    { id: follow_up.id, agent: AiFollowUp::DISPLAY_NAME, status: follow_up.status, objective: follow_up.objective,
      attempts: "#{follow_up.attempts}/#{follow_up.max_attempts}", next_at: local(follow_up.next_run_at),
      outcome: follow_up.outcome, live: follow_up.live?,
      last_events: Array(follow_up.log).last(5).map { |e| [e['kind'], e['text']].compact.join(': ') } }
  end
end
