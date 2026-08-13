# frozen_string_literal: true

# @tickets_cases F3 — Única puerta a Google Calendar para las reuniones
# (plan §4.2). Aquí se concentra TODA la tolerancia a fallas:
#
#   * cuenta sin flag `google_calendar`      → `local_only`
#   * organizador sin Calendar conectado     → `local_only`
#   * Google responde error                  → `failed` + `sync_error`
#
# En los tres casos la reunión **igual queda creada** en MGCI. Ese es el
# corazón de la Opción B: el espejo es un extra, nunca un requisito.
#
# También decide el `sendUpdates` a partir del DIFF (§10.2b): mover la fecha o
# cambiar la lista de invitados escribe al cliente; corregir un typo no.
class Cases::Meetings::GoogleMirrorService
  # Campos cuyo cambio SÍ justifica reenviar la invitación por correo.
  NOTIFYING_FIELDS = %w[starts_at ends_at attendee_emails].freeze

  def initialize(meeting)
    @meeting = meeting
    @ticket  = meeting.case_ticket
  end

  # Crea el evento en Google. `changes` no aplica al alta.
  def create
    return mark_local_only unless mirrorable?

    event = service.create_event(
      calendar_id: calendar_id,
      summary: @meeting.title,
      description: @meeting.description,
      location: @meeting.location,
      start_time: @meeting.starts_at,
      end_time: @meeting.ends_at,
      attendees: attendees,
      with_meet: true,
      send_updates: 'all'
    )
    mark_synced(event)
  rescue StandardError => e
    mark_failed(e)
  end

  # Actualiza el evento. `changes` = hash al estilo `saved_changes` para
  # derivar el sendUpdates; sin él se asume que sí hay que notificar.
  def update(changes: nil)
    return mark_local_only unless mirrorable?
    return create if @meeting.google_event_id.blank?

    event = service.update_event(
      @meeting.google_event_id,
      calendar_id: calendar_id,
      summary: @meeting.title,
      description: @meeting.description,
      location: @meeting.location.to_s,
      start_time: @meeting.starts_at,
      end_time: @meeting.ends_at,
      attendees: attendees,
      send_updates: send_updates_for(changes)
    )
    mark_synced(event)
  rescue StandardError => e
    mark_failed(e)
  end

  # Cancela en Google. Una ocurrencia de serie se cancela con PATCH
  # status=cancelled sobre la instancia, NUNCA con DELETE (§8.2).
  def cancel
    return mark_local_only unless mirrorable?
    return true if @meeting.google_event_id.blank?

    if @meeting.case_meeting_series_id.present?
      service.cancel_instance(@meeting.google_event_id, calendar_id: calendar_id)
    else
      service.delete_event(@meeting.google_event_id, calendar_id: calendar_id, send_updates: 'all')
    end
    write!(sync_status: CaseMeeting.sync_statuses[:synced], sync_error: nil)
    true
  rescue StandardError => e
    mark_failed(e)
  end

  # Cancela la SERIE completa operando sobre el evento MAESTRO (§10.2c): Google
  # emite UN solo aviso al cliente. Cancelar ocurrencia por ocurrencia mandaría N
  # correos, y eso está prohibido por el plan.
  def cancel_series(series)
    return false if series.google_event_id.blank? || !mirrorable?

    service.delete_event(
      series.google_event_id,
      calendar_id: series.google_calendar_id.presence || 'primary',
      send_updates: 'all'
    )
    series.update!(sync_status: :synced, sync_error: nil)
    true
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] cancelar serie #{series.id} en Google: #{e.message}")
    series.update!(sync_status: :failed, sync_error: e.message.to_s.truncate(500))
    false
  end

  # ¿Se puede espejar? Cuenta con el flag Y organizador con Calendar conectado.
  def mirrorable?
    integration.present? && @ticket.account.feature_enabled?('google_calendar')
  end

  # Integración de Calendar del ORGANIZADOR (el evento vive en su calendario;
  # reasignar el ticket no lo mueve — §10.3).
  def integration
    return @integration if defined?(@integration)

    @integration = UserCalendarIntegration.find_by(
      account_id: @meeting.account_id,
      user_id: @meeting.organizer_id
    )
  end

  # Invitados: el organizador, el agente asignado al ticket (aunque NO tenga
  # Google conectado: un invitado es solo un correo) y el cliente si aplica.
  def attendees
    emails = [
      integration&.google_email,
      @meeting.organizer&.email,
      @ticket.assignee&.email
    ]
    emails += Array(@meeting.attendee_emails)
    emails.compact_blank.map { |e| e.to_s.downcase }.uniq
  end

  private

  def service
    @service ||= GoogleCalendarService.new(integration)
  end

  def calendar_id
    @meeting.google_calendar_id.presence || 'primary'
  end

  # §10.2b — la regla sale del diff, no de un ajuste.
  def send_updates_for(changes)
    return 'all' if changes.nil?

    touched = changes.keys.map(&:to_s)
    touched.intersect?(NOTIFYING_FIELDS) ? 'all' : 'none'
  end

  # Escritura directa a propósito: el estado del espejo es metadata del sistema,
  # no un cambio del agente — no debe disparar validaciones ni callbacks (ni la
  # firma derivada de `held`/`cancelled` del modelo).
  # rubocop:disable Rails/SkipsModelValidations
  def write!(attrs)
    @meeting.update_columns(attrs.merge(updated_at: Time.current))
  end
  # rubocop:enable Rails/SkipsModelValidations

  def mark_local_only
    write!(sync_status: CaseMeeting.sync_statuses[:local_only], sync_error: nil)
    false
  end

  def mark_synced(event)
    write!(
      google_event_id: event['id'],
      google_calendar_id: calendar_id,
      meeting_url: GoogleCalendarService.meet_url_from(event) || @meeting.meeting_url,
      sync_status: CaseMeeting.sync_statuses[:synced],
      sync_error: nil
    )
    true
  end

  # El fallo NO tumba la reunión: queda `failed` con el error a la vista y la
  # fila ofrece "Reintentar" (endpoint resync).
  def mark_failed(error)
    Rails.logger.error("[GestorTickets] espejo de reunión #{@meeting.id}: #{error.message}")
    write!(sync_status: CaseMeeting.sync_statuses[:failed], sync_error: error.message.to_s.truncate(500))
    false
  end
end
