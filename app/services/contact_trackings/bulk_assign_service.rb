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
#      y los inscribe con TrackingCampaigns::Enroll (proyecto@automatizacion_campanas),
#      que crea el ContactTracking y deja la inscripción. Devuelve
#      { inserted:, skipped:, errors: [] }.
#
# El inbox de la corrida queda FIJADO por la campaña (= inbox de la plantilla); ya
# no se infiere del historial del contacto, para que el seguimiento salga siempre
# por el canal correcto.
# ================================================================================

class ContactTrackings::BulkAssignService
  include ContactTrackings::Eligibility # ACTIVE_STATUSES + reglas compartidas con el preview

  MAX_BULK_ASSIGN = 100 # Límite de seguridad por asignación masiva

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
      status: 'running',
      mode: 'batch',
      audience: { filter_payload: @filter_payload, excluded_contact_ids: @excluded_contact_ids }
    )
  end

  def resolve_contacts
    result = ::Contacts::FilterService.new(@account, @current_user, { 'payload' => @filter_payload }.with_indifferent_access).perform
    contacts = result[:contacts]
    contacts = contacts.where.not(id: @excluded_contact_ids) if @excluded_contact_ids.any?
    contacts
  end

  # proyecto@automatizacion_campanas — cada contacto pasa por TrackingCampaigns::Enroll, el
  # mismo camino que la automatización "Agregar a campaña": la hora sale de la ventana de la
  # campaña (inicio, espera, horario del inbox) y queda registrada la inscripción, entre o no.
  def process_contact(contact, _template)
    entry = TrackingCampaigns::Enroll.new(@campaign, contact, source: 'batch', agent: @current_user,
                                                              skip_active: @skip_active).call
    entry.enrolled? ? @results[:inserted] += 1 : @results[:skipped] += 1
  rescue StandardError => e
    Rails.logger.error "[BulkAssignService] Error en contacto #{contact.id}: #{e.message}"
    add_error(contact, "Error inesperado: #{e.message}")
  end

  def add_error(contact, message)
    @results[:errors] << { contact_id: contact.id, contact_name: contact.name, message: message }
  end

  def error_result(message)
    { error: message }
  end
end
