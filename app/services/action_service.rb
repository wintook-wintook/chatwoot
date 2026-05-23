class ActionService
  include EmailHelper

  def initialize(conversation)
    @conversation = conversation.reload
    @account = @conversation.account
  end

  def mute_conversation(_params)
    @conversation.mute!
  end

  def snooze_conversation(_params)
    @conversation.snoozed!
  end

  def resolve_conversation(_params)
    @conversation.resolved!
  end

  def change_status(status)
    @conversation.update!(status: status[0])
  end

  def change_priority(priority)
    @conversation.update!(priority: (priority[0] == 'nil' ? nil : priority[0]))
  end

  def add_label(labels)
    return if labels.empty?

    @conversation.reload.add_labels(labels)
  end

  def assign_agent(agent_ids = [])
    return @conversation.update!(assignee_id: nil) if agent_ids[0] == 'nil'

    return unless agent_belongs_to_inbox?(agent_ids)

    @agent = @account.users.find_by(id: agent_ids)

    @conversation.update!(assignee_id: @agent.id) if @agent.present?
  end

  def remove_label(labels)
    return if labels.empty?

    labels = @conversation.label_list - labels
    @conversation.update(label_list: labels)
  end

  def assign_team(team_ids = [])
    # FIXME: The explicit checks for zero or nil (string) is bad. Move
    # this to a separate unassign action.
    should_unassign = team_ids.blank? || %w[nil 0].include?(team_ids[0].to_s)
    return @conversation.update!(team_id: nil) if should_unassign

    # check if team belongs to account only if team_id is present
    # if team_id is nil, then it means that the team is being unassigned
    return unless !team_ids[0].nil? && team_belongs_to_account?(team_ids)

    @conversation.update!(team_id: team_ids[0])
  end

  def remove_assigned_team(_params)
    @conversation.update!(team_id: nil)
  end

  def send_email_transcript(emails)
    emails = emails[0].gsub(/\s+/, '').split(',')

    emails.each do |email|
      email = parse_email_variables(@conversation, email)
      ConversationReplyMailer.with(account: @conversation.account).conversation_transcript(@conversation, email)&.deliver_later
    end
  end

  # proyecto@automatizaciones: asigna el tipo de oportunidad y el proceso default del Kanban a la conversación.
  # Al asignar 'nil' limpia ambos campos. Al asignar un tipo válido busca su KanbanProcess con default: true
  # para que la conversación aparezca en el tablero Kanban desde el primer momento.
  def assign_kanban_type_process(params)
    kanban_type_process_id = params[0]
    if kanban_type_process_id.to_s == 'nil'
      @conversation.update!(kanban_type_process_id: nil, kanban_process_id: nil)
    else
      ktp = @account.kanban_type_processes.find_by(id: kanban_type_process_id)
      if ktp.present?
        default_process = ktp.kanban_processes.find_by(default: true)
        @conversation.update!(
          kanban_type_process_id: ktp.id,
          kanban_process_id: default_process&.id
        )
      end
    end
  end

  # proyecto@automatizacion_tracking: crea un ContactTracking para el contacto de la conversación
  # usando los datos de la plantilla seleccionada (objective, ai_context, complementary_prompt, whatsapp_templates).
  # Usa el inbox_id de la plantilla si está definido, o el inbox de la conversación como fallback.
  # scheduled_for se fija 5 minutos adelante para pasar la validación de "no en el pasado".
  def assign_tracking_template(params)
    template_id = params[0]
    return if template_id.to_s == 'nil' || template_id.blank?

    template = @account.tracking_templates.find_by(id: template_id)
    return unless template.present?

    # No crear si el contacto ya tiene un seguimiento activo
    active_statuses = %w[pending scheduled active paused]
    return if ContactTracking.where(contact_id: @conversation.contact_id, status: active_statuses).exists?

    inbox_id = template.inbox_id || @conversation.inbox_id
    templates = template.whatsapp_templates.is_a?(Array) ? template.whatsapp_templates : []
    max_att = templates.count { |t| t.present? }.clamp(1, 10)
    max_att = 3 if max_att.zero?

    # proyecto@automatizacion_tracking: calcular scheduled_for usando el intervalo de la plantilla
    # para que el primer intento ocurra al mismo tiempo que los siguientes
    interval_value = template.retry_interval_value.presence || 1
    interval_unit  = template.retry_interval_unit.presence  || 'days'
    interval_minutes = case interval_unit
                       when 'minutes' then interval_value
                       when 'hours'   then interval_value * 60
                       when 'days'    then interval_value * 1440
                       else interval_value * 1440
                       end

    ContactTracking.create!(
      account: @account,
      contact: @conversation.contact,
      conversation: @conversation,
      inbox_id: inbox_id,
      objective: template.objective,
      ai_context: template.ai_context.presence || template.objective,
      complementary_prompt: template.complementary_prompt,
      whatsapp_templates: templates,
      keyword_actions: template.keyword_actions.is_a?(Array) ? template.keyword_actions : [],
      max_attempts: max_att,
      scheduled_for: Time.current + interval_minutes.minutes,
      retry_interval_value: interval_value,
      retry_interval_unit: interval_unit
    )

    # Re-encolar el analyzer para que el bot responda al mensaje que disparó la
    # automatización, en caso de que el primer análisis haya corrido antes de que
    # existiera el tracking (race condition con EventDispatcherJob).
    last_incoming = @conversation.messages.where(message_type: :incoming).last
    if last_incoming && last_incoming.created_at > 60.seconds.ago
      ContactTrackingResponseAnalyzerJob.set(wait: 3.seconds).perform_later(last_incoming.id)
    end
  rescue StandardError => e
    Rails.logger.error "[AutomationAction] assign_tracking_template error: #{e.message}"
  end

  private

  def agent_belongs_to_inbox?(agent_ids)
    member_ids = @conversation.inbox.members.pluck(:user_id)
    assignable_agent_ids = member_ids + @account.administrators.ids

    assignable_agent_ids.include?(agent_ids[0])
  end

  def team_belongs_to_account?(team_ids)
    @account.team_ids.include?(team_ids[0])
  end

  def conversation_a_tweet?
    return false if @conversation.additional_attributes.blank?

    @conversation.additional_attributes['type'] == 'tweet'
  end
end

ActionService.include_mod_with('ActionService')
