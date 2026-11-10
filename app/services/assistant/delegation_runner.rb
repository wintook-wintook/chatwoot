# frozen_string_literal: true

# Asistente (Dali) — D3: hace la delegación confirmada. Arma el seguimiento igual que
# la ventana «Delegar a agente IA»: toma del agente sus instrucciones, preguntas,
# palabras clave, calendarios y plantillas de WhatsApp, y le suma el objetivo y la
# instrucción de este cliente. Con caso, el seguimiento queda ligado al caso y se
# anota en su bitácora. Se incluye en Assistant::Executor.
module Assistant::DelegationRunner
  ACTION_LABELS = { 'pause' => 'pausado', 'resume' => 'reanudado', 'cancel' => 'cancelado' }.freeze

  def run_delegate(payload)
    conversation = @tools.find_conversation(payload['conversation_id'])
    agent = @account.tracking_templates.where(archived_at: nil).find(payload['agent_id'])
    ticket = payload['case_id'].present? ? @tools.cases.find(payload['case_id']) : nil
    tracking = ContactTracking.create!(tracking_attrs(payload, conversation, agent))
    link_case(ticket, tracking, agent) if ticket
    done("Seguimiento delegado a #{agent.name}", ticket ? "#{base}/tickets/#{ticket.id}" : "#{base}/contacts/#{conversation.contact_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_tracking_action(payload)
    tracking = @tools.visible_tracking(payload['tracking_id'])
    action = payload['action'].to_s
    raise Assistant::Executor::Refused, 'Acción no válida.' unless ACTION_LABELS.key?(action)

    ok = tracking.public_send("#{action}!")
    raise Assistant::Executor::Refused, "El seguimiento está #{tracking.status}: no se puede." unless ok

    done("Seguimiento #{ACTION_LABELS[action]}", "#{base}/contacts/#{tracking.contact_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  # Seguimiento IA — lo crea con las mismas reglas que el botón del caso (AiFollowUps::Creator).
  def run_follow_up(payload)
    conversation = @tools.find_conversation(payload['conversation_id'])
    ticket = payload['case_id'].present? ? @tools.cases.find(payload['case_id']) : nil
    params = payload.slice('objective', 'starts_at', 'max_attempts', 'interval_value', 'interval_unit',
                           'template_name', 'template_language')
                    .merge('instructions' => payload['instruction'], 'time_zone' => @zone.tzinfo.name)
    AiFollowUps::Creator.new(account: @account, user: @user, conversation: conversation, case_ticket: ticket,
                             params: params).call
    done("Seguimiento delegado a #{AiFollowUp::DISPLAY_NAME}",
         ticket ? "#{base}/tickets/#{ticket.id}" : "#{base}/contacts/#{conversation.contact_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_follow_up_action(payload)
    follow_up = @tools.visible_follow_up(payload['follow_up_id'])
    action = payload['action'].to_s
    raise Assistant::Executor::Refused, 'Acción no válida.' unless ACTION_LABELS.key?(action)
    raise Assistant::Executor::Refused, "Está #{follow_up.status}: no se puede." unless follow_up.public_send("#{action}!", by: @user)

    done("#{AiFollowUp::DISPLAY_NAME} #{ACTION_LABELS[action]}", "#{base}/contacts/#{follow_up.contact_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def tracking_attrs(payload, conversation, agent)
    { account: @account, contact_id: conversation.contact_id, conversation: conversation, inbox_id: conversation.inbox_id,
      tracking_template: agent, status: 'pending', objective: payload['objective'].presence || agent.objective,
      scheduled_for: time(payload['starts_at']) || 5.minutes.from_now }
      .merge(rhythm_attrs(payload, agent)).merge(agent_attrs(payload, agent))
  end

  # Intentos y cada cuánto. Con plantillas de WhatsApp, un intento por plantilla.
  def rhythm_attrs(payload, agent)
    templates = Array(agent.whatsapp_templates).compact_blank
    value = payload['interval_value'].to_i
    { max_attempts: templates.any? ? templates.size : payload['max_attempts'].to_i.clamp(1, 10),
      retry_interval_value: value.positive? ? value : 1,
      retry_interval_unit: payload['interval_unit'].presence_in(%w[minutes hours days]) || 'days',
      whatsapp_templates: templates }
  end

  # Lo que trae el agente, más la instrucción para este cliente.
  def agent_attrs(payload, agent)
    { ai_context: [agent.ai_context, instruction_text(payload)].compact_blank.join("\n\n"),
      complementary_prompt: agent.complementary_prompt, keyword_actions: agent.keyword_actions || [],
      calendar_integration_ids: agent.calendar_integration_ids || [] }
  end

  def instruction_text(payload)
    return nil if payload['instruction'].blank?

    "Instrucción para este seguimiento: #{payload['instruction']}"
  end

  def link_case(ticket, tracking, agent)
    ticket.update!(contact_tracking: tracking)
    ticket.case_events.create!(account: @account, event_type: :tracking_triggered, origin: :agent, actor: @user,
                               payload: { agent: agent.name, objective: tracking.objective, tracking_id: tracking.id })
  end
end
