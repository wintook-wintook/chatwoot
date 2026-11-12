# frozen_string_literal: true

# Asistente (Dali) — Seguimiento IA, el agente nuevo con herramientas:
#   • propose_follow_up: delegar el seguimiento del cliente (no se elige agente);
#   • propose_follow_up_action: pausarlo, reanudarlo o cancelarlo.
# tracking_status (DelegationTools) también los lista. Se incluye en Assistant::Tools.
module Assistant::FollowUpTools
  # Seguimiento IA — delegar al agente nuevo (no se elige agente). Base: el que ya corre en la
  # conversación (se reemplaza), luego la plantilla de seguimiento nombrada (preset) y encima lo
  # que dijo el usuario. Si ya hay uno vivo, arranca por omisión cuando tocaba su siguiente intento.
  def prepare_follow_up(args)
    conversation = delegation_conversation(args)
    raise ArgumentError, 'Necesito una conversación del cliente para delegar el seguimiento.' unless conversation

    live = AiFollowUp.live.find_by(conversation_id: conversation.id)
    preset = follow_up_preset(args['preset'])
    args = follow_up_base(live, preset).merge(args.compact_blank)
    raise ArgumentError, 'Dime qué debe lograr el seguimiento.' if args['objective'].blank?

    payload = follow_up_payload(conversation, args, live)
    [payload, follow_up_labels(conversation, args, payload, live, preset)]
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

  def follow_up_payload(conversation, args, live)
    starts = parse_local(args['starts_at']) || (live&.next_run_at if live&.next_run_at&.future?)
    { 'conversation_id' => conversation.display_id, 'case_id' => args['case_id'],
      'objective' => args['objective'].to_s.first(1000), 'instruction' => args['instruction'].to_s,
      'starts_at' => starts&.iso8601, 'on_finish' => args['on_finish'].presence_in(AiFollowUp::ON_FINISH),
      'replace' => live.present? }.compact
      .merge(follow_up_rhythm(args), follow_up_template(conversation, args['template_name']))
  end

  def follow_up_labels(conversation, args, payload, live, preset)
    { 'agent' => AiFollowUp::DISPLAY_NAME, 'conversation' => conversation_label(conversation),
      'target' => delegate_target(args), 'template' => payload['template_name'], 'preset' => preset&.name,
      'presets' => @account.ai_follow_up_presets.ordered.limit(50).map { |p| { 'id' => p.id, 'name' => p.name, 'fields' => p.fields } },
      'whatsapp_templates' => AiFollowUps::Templates.new(conversation).available.map { |t| t.slice(:name, :language) },
      'replaces' => live && { 'attempts' => live.attempts, 'max_attempts' => live.max_attempts,
                              'next_at' => local(live.next_run_at), 'objective' => live.objective } }.compact
  end

  # Lo del seguimiento que corre y de la plantilla, con los nombres de los argumentos de la tarjeta.
  def follow_up_base(live, preset)
    [live, preset].compact.each_with_object({}) do |source, base|
      base.merge!({ 'objective' => source.objective, 'instruction' => source.instructions,
                    'max_attempts' => source.max_attempts, 'interval_value' => source.interval_value,
                    'interval_unit' => source.interval_unit, 'on_finish' => source.on_finish,
                    'template_name' => source.template_name }.compact_blank)
    end
  end

  # La plantilla de seguimiento por su nombre (sin importar mayúsculas); nombrada y no existe → error.
  def follow_up_preset(name)
    return if name.blank?

    @account.ai_follow_up_presets.find_by('lower(name) = ?', name.to_s.strip.downcase) ||
      raise(ArgumentError, "No hay una plantilla de seguimiento llamada «#{name}».")
  end

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
