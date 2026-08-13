# frozen_string_literal: true

# ================================================================================
# @tickets_cases F1 — Reuniones de un ticket (ver docs/tickets_reuniones_plan.md §4.5)
# ================================================================================
# GET    /api/v1/accounts/:id/case_tickets/:case_ticket_id/meetings
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/meetings
# PATCH  /api/v1/accounts/:id/case_tickets/:case_ticket_id/meetings/:id
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/meetings/:id
# PATCH  …/meetings/:id/hold    marcar realizada / no asistió
# PATCH  …/meetings/:id/cancel  scope: 'one' | 'all'
# POST   …/meetings/:id/resync  reintentar el espejo con Google (llega en F3)
#
# La autorización es la misma de `case_tasks_controller` / `case_notes_controller`:
# scoping por `Current.account` y ticket cerrado = solo lectura.
#
# ⚠️ F1 NO habla con Google. Toda reunión nace `local_only`; el espejo (y con él
# `pending`/`synced`/`failed`) lo decide `Cases::Meetings::GoogleMirrorService` en F3.
# ================================================================================

class Api::V1::Accounts::CaseMeetingsController < Api::V1::Accounts::BaseController
  include CaseMeetingSerializer

  FROZEN_MSG = 'Ticket cerrado: no se pueden modificar las reuniones. Reábrelo si necesitas cambiarlas.'
  NO_MIRROR_MSG = 'Esta reunión vive solo en el sistema: el organizador no tiene Google Calendar conectado.'

  before_action :set_ticket
  before_action :set_meeting, only: %i[update destroy hold cancel resync]
  before_action :block_if_frozen, only: %i[create update destroy hold cancel resync]

  def index
    # @tickets_cases F3 — reconciliación perezosa (§5): antes de responder se
    # relee desde Google lo que pudo cambiar allá. Con throttle de 60 s y solo si
    # hay reuniones futuras espejadas, así que casi siempre cuesta 0 llamadas.
    Cases::Meetings::ReconcileService.new(@ticket).perform
    meetings = @ticket.case_meetings.ordered
    meetings = meetings.where(case_task_id: params[:case_task_id]) if params[:case_task_id].present?
    render json: {
      case_meetings: meetings.map { |m| meeting_json(m) },
      # La UI necesita saber si puede ofrecer el espejo: agentes con Calendar conectado.
      available_organizers: available_organizers
    }
  end

  def create
    meeting = @ticket.case_meetings.build(meeting_params)
    meeting.account = Current.account
    # Organizador por defecto = quien agenda: el evento vive en SU calendario y
    # reasignar el ticket no lo mueve (§10.3).
    meeting.organizer_id ||= current_user&.id
    # Nace pendiente: el job decide si queda `synced` o `local_only` (§4.2).
    meeting.sync_status = :pending

    if meeting.save
      log_event(:meeting_scheduled, meeting)
      # El espejo va FUERA del request: agendar no depende de la latencia de Google.
      Cases::MeetingSyncJob.perform_later(meeting.id, 'create')
      render json: { case_meeting: meeting_json(meeting) }, status: :created
    else
      render json: { error: meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    moved = date_change?(meeting_params)

    if @meeting.update(meeting_params)
      # Solo se anota en la bitácora si de verdad se movió de fecha/hora: editar el
      # título no merece una línea en el Avance.
      log_event(:meeting_updated, @meeting) if moved
      # El diff decide si Google reenvía la invitación al cliente (§10.2b).
      Cases::MeetingSyncJob.perform_later(@meeting.id, 'update', @meeting.saved_changes.except('updated_at'))
      render json: { case_meeting: meeting_json(@meeting) }
    else
      render json: { error: @meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Borrar la fila también retira la cita del calendario del organizador: si no,
    # el cliente se queda citado a una reunión que en MGCI ya no existe.
    Cases::Meetings::GoogleMirrorService.new(@meeting).cancel if @meeting.google_event_id.present?
    @meeting.destroy
    head :no_content
  end

  # Marcar realizada / no asistió. El quién/cuándo lo deriva el modelo.
  def hold
    status = params[:status].presence || 'held'
    return render json: { error: 'Estado inválido' }, status: :unprocessable_entity unless %w[held no_show].include?(status)

    if @meeting.update(status: status)
      log_event(:meeting_held, @meeting)
      render json: { case_meeting: meeting_json(@meeting) }
    else
      render json: { error: @meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # `scope: 'one'` (default) cancela esta reunión; `'all'` cancela toda la serie.
  # ('following' queda diferido, ver §4.5 del plan.)
  def cancel
    scope = params[:scope].presence || 'one'
    return render json: { error: 'Alcance inválido' }, status: :unprocessable_entity unless %w[one all].include?(scope)

    if scope == 'all' && @meeting.case_meeting_series_id.blank?
      return render json: { error: 'La reunión no pertenece a una serie' }, status: :unprocessable_entity
    end

    if scope == 'all'
      cancel_series
    else
      @meeting.update!(status: :cancelled)
      Cases::MeetingSyncJob.perform_later(@meeting.id, 'cancel')
    end
    log_event(:meeting_cancelled, @meeting, scope: scope)
    render json: { case_meeting: meeting_json(@meeting.reload) }
  end

  # Reintentar el espejo tras un fallo (o tras conectar Calendar). Si no hay a
  # dónde espejar, lo dice en vez de dejar la fila girando en `pending`.
  def resync
    return render json: { error: NO_MIRROR_MSG }, status: :unprocessable_entity unless mirrorable?

    @meeting.update!(sync_status: :pending, sync_error: nil)
    operation = @meeting.google_event_id.present? ? 'update' : 'create'
    Cases::MeetingSyncJob.perform_later(@meeting.id, operation)
    render json: { case_meeting: meeting_json(@meeting.reload) }
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def set_meeting
    @meeting = @ticket.case_meetings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Reunión no encontrada' }, status: :not_found
  end

  def mirrorable?
    Cases::Meetings::GoogleMirrorService.new(@meeting).mirrorable?
  end

  def block_if_frozen
    render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?
  end

  def meeting_params
    permitted = params.require(:case_meeting).permit(
      :title, :description, :starts_at, :ends_at, :time_zone, :location,
      :notify_client, :case_task_id, :case_meeting_series_id, :organizer_id,
      attendee_emails: []
    )
    # El organizador debe ser un usuario de la cuenta (si no, se ignora).
    permitted[:organizer_id] = Current.account.users.where(id: permitted[:organizer_id]).pick(:id) if permitted.key?(:organizer_id)
    permitted
  end

  # ¿La edición mueve la reunión de fecha/hora? (compara contra lo ya guardado)
  def date_change?(attrs)
    %i[starts_at ends_at].any? do |field|
      attrs[field].present? && Time.zone.parse(attrs[field].to_s) != @meeting.public_send(field)
    end
  end

  # Cancela todas las ocurrencias vivas de la serie y la serie misma.
  # ⚠️ En Google se opera SOBRE EL MAESTRO (§10.2c): un bucle de cancelaciones por
  # ocurrencia le mandaría N correos al cliente. Aquí solo se marcan las filas; el
  # aviso único sale del maestro, que gestiona la serie (F4).
  def cancel_series
    series = @meeting.case_meeting_series
    series.case_meetings.active.find_each { |m| m.update!(status: :cancelled) }
    Cases::Meetings::GoogleMirrorService.new(@meeting).cancel_series(series)
    series.cancel!(actor: current_user)
  end

  def log_event(event_type, meeting, scope: 'one')
    @ticket.case_events.create!(
      account: Current.account,
      event_type: event_type,
      origin: current_user ? :agent : :system,
      actor: current_user,
      # La reunión puede colgar de una tarea: así la bitácora la ubica igual que las notas.
      case_task: meeting.case_task,
      payload: {
        meeting_id: meeting.id,
        sequence: meeting.sequence,
        folio: meeting.folio,
        title: meeting.title,
        starts_at: meeting.starts_at,
        status: meeting.status,
        series_sequence: meeting.case_meeting_series&.sequence,
        scope: scope
      }
    )
  end

  # Agentes de la cuenta con Google Calendar conectado (los que pueden ser
  # organizadores de verdad cuando F3 encienda el espejo).
  def available_organizers
    UserCalendarIntegration.where(account: Current.account).includes(:user).map do |integration|
      { id: integration.user_id, name: integration.user&.name, google_email: integration.google_email }
    end
  end
end
