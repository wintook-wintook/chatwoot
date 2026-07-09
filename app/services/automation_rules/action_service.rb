class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end
  
  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
    end
  end

  # proyecto@automatizacion_tracking: pausa el seguimiento activo del contacto en el inbox indicado
  # en las condiciones de la regla. Si no hay condición inbox_id, pausa todos los activos.
  def pause_active_tracking(_params)
    active_statuses = %w[pending scheduled active]

    inbox_condition = @rule.conditions.find { |c| c['attribute_key'] == 'inbox_id' }
    trackings = ContactTracking.where(contact_id: @conversation.contact_id, status: active_statuses)
    trackings = trackings.where(inbox_id: inbox_condition['values']) if inbox_condition.present?

    trackings.each(&:pause!)
  rescue StandardError => e
    Rails.logger.error "[AutomationAction] pause_active_tracking error: #{e.message}"
  end

  # proyecto@automatizacion_tracking: cancela el seguimiento activo del contacto en el inbox indicado
  # en las condiciones de la regla. Si no hay condición inbox_id, cancela todos los activos.
  def cancel_active_tracking(_params)
    active_statuses = %w[pending scheduled active paused]

    inbox_condition = @rule.conditions.find { |c| c['attribute_key'] == 'inbox_id' }
    trackings = ContactTracking.where(contact_id: @conversation.contact_id, status: active_statuses)
    trackings = trackings.where(inbox_id: inbox_condition['values']) if inbox_condition.present?

    trackings.each(&:cancel!)
  rescue StandardError => e
    Rails.logger.error "[AutomationAction] cancel_active_tracking error: #{e.message}"
  end
end
