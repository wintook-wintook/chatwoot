# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — CREAR EL SEGUIMIENTO DE UN INSCRITO
# ================================================================================
# Lo que hacía BulkAssignService por cada contacto, sacado para que lo usen igual el lote
# y la automatización (TrackingCampaigns::Enroll):
#
#   · el canal es SIEMPRE el inbox de la campaña: se reusa una conversación del contacto
#     en ese inbox si la hay; si no, se abre una nueva con una nota privada;
#   · el seguimiento copia la configuración de la plantilla (Agente IA) de la campaña;
#   · se encola ContactTrackingJob para la hora calculada (ExecutePendingJob también lo
#     toma a su hora, como siempre).
# ================================================================================
class TrackingCampaigns::TrackingBuilder
  DEFAULT_MAX_ATTEMPTS = 3

  # conversation: la que disparó la automatización; se usa si es del inbox de la campaña.
  def initialize(campaign, contact, agent: nil, note: nil, conversation: nil)
    @campaign = campaign
    @account = campaign.account
    @contact = contact
    @conversation = conversation if conversation&.inbox_id == campaign.inbox_id
    @agent = agent || @account.users.first
    @note = note || '📋 Seguimiento asignado de forma masiva'
  end

  # La conversación que va a usar el seguimiento: la del contacto en el inbox de la
  # campaña, la más reciente abierta primero. nil si no tiene.
  def existing_conversation
    @existing_conversation ||= @conversation || @contact.conversations
                                                        .where(inbox_id: @campaign.inbox_id)
                                                        .order(status: :asc, last_activity_at: :desc)
                                                        .first
  end

  # El id del ContactTracking creado, programado para `scheduled_for`.
  def create!(scheduled_for:)
    @scheduled_for = scheduled_for
    conversation_id = existing_conversation&.id || open_conversation&.id
    tracking_id = insert_tracking(conversation_id)
    ContactTrackingJob.set(wait_until: @scheduled_for).perform_later(tracking_id)
    tracking_id
  end

  private

  def template
    @template ||= @campaign.tracking_template
  end

  # insert! y no create!, como hacía el lote: ContactTracking valida en el alta que
  # scheduled_for no esté en el pasado, y una inscripción programada para "ahora" ya es
  # pasado cuando se valida. Las otras reglas (un Agente IA activo por inbox, conversación
  # del mismo inbox) ya las resolvieron Enroll y #existing_conversation.
  # rubocop:disable Rails/SkipsModelValidations
  def insert_tracking(conversation_id)
    now = Time.current
    ContactTracking.insert!(tracking_attributes(conversation_id).merge(created_at: now, updated_at: now),
                            returning: [:id]).rows.first.first
  end
  # rubocop:enable Rails/SkipsModelValidations

  def tracking_attributes(conversation_id)
    {
      account_id: @account.id, contact_id: @contact.id, inbox_id: @campaign.inbox_id, conversation_id: conversation_id,
      tracking_template_id: template.id, tracking_campaign_id: @campaign.id, objective: template.objective,
      scheduled_for: @scheduled_for, max_attempts: DEFAULT_MAX_ATTEMPTS, attempt_count: 0,
      retry_interval_value: template.retry_interval_value || 30, retry_interval_unit: template.retry_interval_unit || 'minutes',
      ai_context: template.ai_context, complementary_prompt: template.complementary_prompt,
      whatsapp_templates: template.whatsapp_templates || [], keyword_actions: template.keyword_actions || [],
      calendar_integration_ids: template.calendar_integration_ids || [],
      calendar_event_duration: template.calendar_event_duration || 30,
      response_adjustments_count: 0, status: 'pending'
    }
  end

  def open_conversation
    return nil unless @agent

    contact_inbox = ContactInboxBuilder.new(contact: @contact, inbox: @campaign.inbox).perform
    conversation = ConversationBuilder.new(
      params: ActionController::Parameters.new(assignee_id: @agent.id),
      contact_inbox: contact_inbox
    ).perform
    Messages::MessageBuilder.new(@agent, conversation, { content: @note, private: true }).perform
    conversation
  rescue StandardError => e
    Rails.logger.warn "[TrackingCampaigns::TrackingBuilder] No se pudo abrir conversación: #{e.message}"
    nil
  end
end
