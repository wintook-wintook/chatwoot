# proyecto@bulk_tracking_assign
# frozen_string_literal: true

# ================================================================================
# proyecto@bulk_tracking_assign
# ================================================================================
# Servicio: ContactTrackings::BulkAssignService
# Descripción: Aplica una TrackingTemplate a un conjunto de contactos resuelto
#              por filtro (mismo formato que Contacts::FilterService), excluyendo
#              los contact_ids indicados. Reutiliza los mismos patrones de
#              resolución de inbox/conversación que ContactTrackingImportService.
#
# Retorna:
#   { inserted: N, skipped: N, errors: [{ contact_id:, contact_name:, message: }] }
# ================================================================================

class ContactTrackings::BulkAssignService
  ACTIVE_STATUSES      = %w[pending scheduled active paused].freeze
  DEFAULT_MAX_ATTEMPTS = 3
  MAX_BULK_ASSIGN      = 30 # Límite de seguridad por asignación masiva

  def initialize(account:, current_user:, filter_payload:, template_id:, scheduled_for:,
                  excluded_contact_ids: [], skip_active: true)
    @account              = account
    @current_user         = current_user
    @filter_payload       = filter_payload
    @template_id          = template_id
    @scheduled_for        = scheduled_for
    @excluded_contact_ids = Array(excluded_contact_ids).map(&:to_i)
    @skip_active          = skip_active
    @results              = { inserted: 0, skipped: 0, errors: [] }
  end

  def call
    template = @account.tracking_templates.find_by(id: @template_id)
    return error_result('Plantilla no encontrada') unless template

    return error_result('La fecha debe ser futura') if @scheduled_for.blank? || @scheduled_for <= Time.current

    contacts = resolve_contacts
    contacts_count = contacts.count

    if contacts_count > MAX_BULK_ASSIGN
      return error_result(
        "La selección tiene #{contacts_count} contactos y el límite es de #{MAX_BULK_ASSIGN}. " \
        'Reduce el filtro o excluye contactos antes de confirmar.'
      )
    end

    contacts.find_each { |contact| process_contact(contact, template) }

    @results
  end

  private

  def resolve_contacts
    result = ::Contacts::FilterService.new(@account, @current_user, { 'payload' => @filter_payload }.with_indifferent_access).perform
    contacts = result[:contacts]
    contacts = contacts.where.not(id: @excluded_contact_ids) if @excluded_contact_ids.any?
    contacts
  end

  def process_contact(contact, template)
    if @skip_active && ContactTracking.where(contact_id: contact.id, status: ACTIVE_STATUSES).exists?
      @results[:skipped] += 1
      return
    end

    inbox_id, conversation_id = resolve_inbox_and_conversation(contact, template)
    unless inbox_id
      add_error(contact, "No se pudo determinar el inbox para este contacto. Configura un inbox en la plantilla '#{template.name}'.")
      return
    end

    conversation_id ||= open_conversation_with_private_note(contact, inbox_id)&.id

    create_tracking(contact, inbox_id, conversation_id, template)
  rescue StandardError => e
    Rails.logger.error "[BulkAssignService] Error en contacto #{contact.id}: #{e.message}"
    add_error(contact, "Error inesperado: #{e.message}")
  end

  def create_tracking(contact, inbox_id, conversation_id, template)
    now = Time.current

    result = ContactTracking.insert!(
      {
        account_id:                 @account.id,
        contact_id:                 contact.id,
        inbox_id:                   inbox_id,
        conversation_id:            conversation_id,
        tracking_template_id:       template.id,
        objective:                  template.objective,
        scheduled_for:              @scheduled_for,
        max_attempts:               DEFAULT_MAX_ATTEMPTS,
        attempt_count:              0,
        retry_interval_value:       template.retry_interval_value || 30,
        retry_interval_unit:        template.retry_interval_unit || 'minutes',
        ai_context:                 template.ai_context,
        complementary_prompt:       template.complementary_prompt,
        whatsapp_templates:         template.whatsapp_templates || [],
        keyword_actions:            template.keyword_actions || [],
        calendar_integration_ids:   template.calendar_integration_ids || [],
        calendar_event_duration:    template.calendar_event_duration || 30,
        response_adjustments_count: 0,
        status:                     'pending',
        created_at:                 now,
        updated_at:                 now
      },
      returning: [:id]
    )

    tracking_id = result.rows.first.first
    ContactTrackingJob.set(wait_until: @scheduled_for).perform_later(tracking_id)
    @results[:inserted] += 1
  rescue StandardError => e
    add_error(contact, "Error al crear tracking: #{e.message}")
  end

  # Mismo criterio que ContactTrackingImportService:
  # usa la conversación más reciente del contacto, o el inbox de la plantilla si no tiene ninguna.
  def resolve_inbox_and_conversation(contact, template)
    conversation = contact.conversations.order(status: :asc, last_activity_at: :desc).first
    return [conversation.inbox_id, conversation.id] if conversation

    [template.inbox_id.presence, nil]
  end

  def open_conversation_with_private_note(contact, inbox_id)
    inbox = @account.inboxes.find_by(id: inbox_id)
    return nil unless inbox

    agent = @current_user || @account.users.first
    return nil unless agent

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    conversation = ConversationBuilder.new(
      params: ActionController::Parameters.new(assignee_id: agent.id),
      contact_inbox: contact_inbox
    ).perform

    Messages::MessageBuilder.new(
      agent, conversation, { content: '📋 Seguimiento asignado de forma masiva', private: true }
    ).perform

    conversation
  rescue StandardError => e
    Rails.logger.warn "[BulkAssignService] No se pudo abrir conversación: #{e.message}"
    nil
  end

  def add_error(contact, message)
    @results[:errors] << { contact_id: contact.id, contact_name: contact.name, message: message }
  end

  def error_result(message)
    { inserted: 0, skipped: 0, errors: [{ contact_id: nil, contact_name: nil, message: message }] }
  end
end
