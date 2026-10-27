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
#      Con launch: false la campaña queda Guardada (saved): se guarda la audiencia y no se
#      encola nada; la pone en curso TrackingCampaigns::Launch, que llama a #enqueue!.
#      Mientras siga Guardada se puede modificar (#update!); ya en curso, no.
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

  MAX_BULK_ASSIGN = 1000 # Límite de seguridad por asignación masiva (Fase 2: antes 100)
  # proyecto@automatizacion_campanas — Fase 2: el lote se inscribe por tandas, cada una en su
  # propio job (BulkAssignJob con cursor): un reinicio de Sidekiq no corta la campaña a medias.
  BATCH_SIZE = 100

  # window: la ventana de la campaña por lote (proyecto@automatizacion_campanas):
  #   { ends_at:, entry_delay_minutes:, respect_working_hours: } — todo opcional.
  # audience_source: cómo se eligió la audiencia ({ type: 'segment', segment_id: } o
  #   { type: 'label', label: }), para volver a mostrarla al modificar una Guardada.
  def initialize(account:, current_user:, filter_payload:, template_id:, scheduled_for:, # rubocop:disable Metrics/ParameterLists
                 campaign_name:, excluded_contact_ids: [], skip_active: true, campaign: nil, window: {}, launch: true,
                 audience_source: nil, email_subject: nil, purpose: nil)
    @account              = account
    @current_user         = current_user
    @filter_payload       = filter_payload
    @template_id          = template_id
    @scheduled_for        = scheduled_for
    @campaign_name        = campaign_name.to_s.strip
    @excluded_contact_ids = Array(excluded_contact_ids).map(&:to_i)
    @skip_active          = skip_active
    @campaign             = campaign
    @window               = window.to_h.symbolize_keys.compact
    @launch               = launch
    @audience_source      = audience_source.presence
    @email_subject        = email_subject.to_s.strip.presence # prospeccion F1
    @purpose              = TrackingCampaign::PURPOSES.include?(purpose.to_s) ? purpose.to_s : 'follow_up' # prospeccion V0
    @results              = { inserted: 0, skipped: 0, errors: [] }
  end

  # Fase 1 (síncrona): valida, crea la campaña y encola el procesamiento.
  def call
    template = @account.tracking_templates.find_by(id: @template_id)
    error, contacts_count = validation(template)
    return error_result(error) if error

    campaign = @account.tracking_campaigns.create!(campaign_attributes(template).merge(user_id: @current_user&.id))
    return saved_result(campaign, contacts_count) unless @launch

    enqueue_job(campaign)
    { queued: contacts_count, campaign_id: campaign.id, campaign_name: campaign.name }
  end

  # Modificar una campaña Guardada (@campaign) con las mismas validaciones que al crearla.
  # Sigue Guardada: ponerla en curso es aparte (TrackingCampaigns::Launch).
  def update!
    template = @account.tracking_templates.find_by(id: @template_id)
    error, contacts_count = validation(template)
    return error_result(error) if error

    @campaign.update!(campaign_attributes(template).merge(status: 'saved', daily_cap: nil))
    saved_result(@campaign, contacts_count)
  end

  # Poner en curso una campaña Guardada (lo llama TrackingCampaigns::Launch, ya con @campaign y
  # @scheduled_for resueltos): la audiencia se resuelve AHORA, con los contactos del momento.
  # El bloque abre la campaña (cambia su estado) DESPUÉS de validar y ANTES de encolar: el
  # job inscribe solo si la campaña ya acepta entradas.
  def enqueue!
    return error_result('La plantilla de la campaña ya no existe.') unless @campaign.tracking_template
    return error_result('El Agente IA de la campaña no tiene un inbox configurado.') if @campaign.inbox_id.blank?

    contacts_count = resolve_contacts.count
    count_error = audience_error(contacts_count)
    return error_result(count_error) if count_error

    yield if block_given?
    enqueue_job(@campaign)
    { queued: contacts_count, campaign_id: @campaign.id, campaign_name: @campaign.name }
  end

  def enqueue_job(campaign)
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
  end

  # Fase 2 (background): aplica la plantilla contacto por contacto, en tandas de BATCH_SIZE
  # por id. Devuelve también next_cursor: el último id de la tanda si quedan más (el job encola
  # la siguiente), o nil si terminó. Ya inscritos no se repiten: Enroll los omite.
  def process!(after_id: 0)
    template = @account.tracking_templates.find_by(id: @template_id)
    return @results unless template && @campaign

    batch = resolve_contacts.reorder('contacts.id').where('contacts.id > ?', after_id.to_i).limit(BATCH_SIZE).to_a
    batch.each { |contact| process_contact(contact, template) }
    @results.merge(next_cursor: batch.size == BATCH_SIZE ? batch.last.id : nil)
  end

  private

  # [error, contactos de la audiencia]
  def validation(template)
    error = template ? creation_error(template) : 'Plantilla no encontrada'
    return [error] if error

    contacts_count = resolve_contacts.count
    [audience_error(contacts_count), contacts_count]
  end

  def saved_result(campaign, contacts_count)
    { saved: true, contacts: contacts_count, campaign_id: campaign.id, campaign_name: campaign.name }
  end

  def creation_error(template)
    return 'El nombre de la campaña es obligatorio' if @campaign_name.blank?

    error = window_error
    return error if error
    # La campaña fija su inbox; sin inbox no hay canal por el cual conversar.
    return if template.inbox_id.present?

    "La plantilla '#{template.name}' no tiene un inbox configurado. Asígnale un inbox antes de lanzar la campaña."
  end

  def window_error
    start_error || end_error
  end

  # Al modificar una Guardada (@campaign) su inicio puede haber pasado: Launch lo corre a ahora.
  def start_error
    return 'La fecha debe ser futura' if @scheduled_for.blank?

    'La fecha debe ser futura' if @campaign.nil? && @scheduled_for <= Time.current
  end

  # El fin no: con la ventana vencida no se podría poner en curso.
  def end_error
    ends_at = @window[:ends_at]
    return unless ends_at
    return 'El fin ya pasó' if @campaign && ends_at <= Time.current

    'El fin debe ser posterior al inicio' if ends_at <= @scheduled_for
  end

  def audience_error(contacts_count)
    return 'La selección no tiene contactos.' if contacts_count.zero?
    return if contacts_count <= MAX_BULK_ASSIGN

    "La selección tiene #{contacts_count} contactos y el límite es de #{MAX_BULK_ASSIGN}. " \
      'Reduce el filtro o excluye contactos antes de confirmar.'
  end

  def campaign_status
    return 'saved' unless @launch

    TrackingCampaign.status_for(@scheduled_for)
  end

  # Sin fin, sin espera o sin la opción de horario = los valores por defecto (al modificar,
  # borrar el fin lo quita).
  def campaign_attributes(template)
    {
      name: @campaign_name,
      tracking_template_id: template.id,
      inbox_id: template.inbox_id,
      objective: template.objective,
      scheduled_for: @scheduled_for,
      # proyecto@automatizacion_campanas: con inicio futuro nace Programada y la abre
      # TrackingCampaigns::WindowJob; las inscripciones no esperan a eso.
      # Guardada (launch: false) no inscribe a nadie hasta TrackingCampaigns::Launch.
      status: campaign_status,
      mode: 'batch',
      audience: { filter_payload: @filter_payload, excluded_contact_ids: @excluded_contact_ids, skip_active: @skip_active,
                  source: @audience_source }.compact,
      ends_at: @window[:ends_at],
      entry_delay_minutes: @window[:entry_delay_minutes] || 0,
      respect_working_hours: @window.fetch(:respect_working_hours, true),
      email_subject: @email_subject, # prospeccion F1: solo cuenta si la bandeja es de correo
      purpose: @purpose # prospeccion V0
    }
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
