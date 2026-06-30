# proyecto@bulk_tracking_assign
# frozen_string_literal: true

# ================================================================================
# proyecto@bulk_tracking_assign
# ================================================================================
# Servicio: ContactTrackings::BulkAssignService
# Descripción: Aplica una TrackingTemplate a un conjunto de contactos resuelto
#              por filtro (mismo formato que Contacts::FilterService), excluyendo
#              los contact_ids indicados.
#
# Flujo en dos fases (@campanas_vendedor):
#   1. #call  (síncrono, request): valida, crea la TrackingCampaign y encola el
#      procesamiento pesado en background. Devuelve { queued:, campaign_id:, campaign_name: }.
#   2. #process! (background, ContactTrackings::BulkAssignJob): recorre los contactos
#      creando los ContactTracking. Devuelve { inserted:, skipped:, errors: [] }.
#
# El inbox de la corrida queda FIJADO por la campaña (= inbox de la plantilla); ya
# no se infiere del historial del contacto, para que el seguimiento salga siempre
# por el canal correcto.
# ================================================================================

class ContactTrackings::BulkAssignService
  ACTIVE_STATUSES      = %w[pending scheduled active paused].freeze
  DEFAULT_MAX_ATTEMPTS = 3
  MAX_BULK_ASSIGN      = 100 # Límite de seguridad por asignación masiva

  def initialize(account:, current_user:, filter_payload:, template_id:, scheduled_for:,
                 campaign_name:, excluded_contact_ids: [], skip_active: true, campaign: nil)
    @account              = account
    @current_user         = current_user
    @filter_payload       = filter_payload
    @template_id          = template_id
    @scheduled_for        = scheduled_for
    @campaign_name        = campaign_name.to_s.strip
    @excluded_contact_ids = Array(excluded_contact_ids).map(&:to_i)
    @skip_active          = skip_active
    @campaign             = campaign
    @results              = { inserted: 0, skipped: 0, errors: [] }
  end

  # Fase 1 (síncrona): valida, crea la campaña y encola el procesamiento.
  def call
    template = @account.tracking_templates.find_by(id: @template_id)
    return error_result('Plantilla no encontrada') unless template

    return error_result('El nombre de la campaña es obligatorio') if @campaign_name.blank?

    return error_result('La fecha debe ser futura') if @scheduled_for.blank? || @scheduled_for <= Time.current

    # La campaña fija su inbox; sin inbox no hay canal por el cual conversar.
    if template.inbox_id.blank?
      return error_result(
        "La plantilla '#{template.name}' no tiene un inbox configurado. " \
        'Asígnale un inbox antes de lanzar la campaña.'
      )
    end

    contacts_count = resolve_contacts.count
    return error_result('La selección no tiene contactos.') if contacts_count.zero?

    if contacts_count > MAX_BULK_ASSIGN
      return error_result(
        "La selección tiene #{contacts_count} contactos y el límite es de #{MAX_BULK_ASSIGN}. " \
        'Reduce el filtro o excluye contactos antes de confirmar.'
      )
    end

    campaign = build_campaign(template)

    ContactTrackings::BulkAssignJob.perform_later(
      {
        account_id: @account.id,
        current_user_id: @current_user&.id,
        filter_payload: @filter_payload,
        template_id: @template_id,
        scheduled_for: @scheduled_for.iso8601,
        excluded_contact_ids: @excluded_contact_ids,
        skip_active: @skip_active,
        campaign_id: campaign.id
      }
    )

    { queued: contacts_count, campaign_id: campaign.id, campaign_name: campaign.name }
  end

  # Fase 2 (background): aplica la plantilla contacto por contacto.
  def process!
    template = @account.tracking_templates.find_by(id: @template_id)
    return @results unless template && @campaign

    resolve_contacts.find_each { |contact| process_contact(contact, template) }
    @results
  end

  private

  def build_campaign(template)
    @account.tracking_campaigns.create!(
      name: @campaign_name,
      tracking_template_id: template.id,
      inbox_id: template.inbox_id,
      user_id: @current_user&.id,
      objective: template.objective,
      scheduled_for: @scheduled_for,
      status: 'running'
    )
  end

  def resolve_contacts
    result = ::Contacts::FilterService.new(@account, @current_user, { 'payload' => @filter_payload }.with_indifferent_access).perform
    contacts = result[:contacts]
    contacts = contacts.where.not(id: @excluded_contact_ids) if @excluded_contact_ids.any?
    contacts
  end

  def process_contact(contact, template)
    inbox_id, conversation_id = resolve_inbox_and_conversation(contact)
    unless inbox_id
      add_error(contact, 'La campaña no tiene un inbox configurado para este seguimiento.')
      return
    end

    # Omitir solo si ya hay un seguimiento activo EN ESTE CANAL (inbox)
    if @skip_active && ContactTracking.exists?(contact_id: contact.id, inbox_id: inbox_id, status: ACTIVE_STATUSES)
      @results[:skipped] += 1
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
        account_id: @account.id,
        contact_id: contact.id,
        inbox_id: inbox_id,
        conversation_id: conversation_id,
        tracking_template_id: template.id,
        tracking_campaign_id: @campaign&.id,
        objective: template.objective,
        scheduled_for: @scheduled_for,
        max_attempts: DEFAULT_MAX_ATTEMPTS,
        attempt_count: 0,
        retry_interval_value: template.retry_interval_value || 30,
        retry_interval_unit: template.retry_interval_unit || 'minutes',
        ai_context: template.ai_context,
        complementary_prompt: template.complementary_prompt,
        whatsapp_templates: template.whatsapp_templates || [],
        keyword_actions: template.keyword_actions || [],
        calendar_integration_ids: template.calendar_integration_ids || [],
        calendar_event_duration: template.calendar_event_duration || 30,
        response_adjustments_count: 0,
        status: 'pending',
        created_at: now,
        updated_at: now
      },
      returning: [:id]
    )

    tracking_id = result.rows.first.first
    ContactTrackingJob.set(wait_until: @scheduled_for).perform_later(tracking_id)
    @results[:inserted] += 1
  rescue StandardError => e
    add_error(contact, "Error al crear tracking: #{e.message}")
  end

  # El inbox queda FIJADO por la campaña (= inbox de la plantilla). Reusa una
  # conversación existente del contacto SOLO si es del mismo inbox; si no, se abre
  # una nueva en el canal de la campaña.
  def resolve_inbox_and_conversation(contact)
    inbox_id = @campaign&.inbox_id
    return [nil, nil] if inbox_id.blank?

    conversation = contact.conversations
                          .where(inbox_id: inbox_id)
                          .order(status: :asc, last_activity_at: :desc)
                          .first
    [inbox_id, conversation&.id]
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
    { error: message }
  end
end
