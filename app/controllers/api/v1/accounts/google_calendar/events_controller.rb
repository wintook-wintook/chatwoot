class Api::V1::Accounts::GoogleCalendar::EventsController < Api::V1::Accounts::BaseController
  before_action :require_integration

  def index
    enabled_ids = @integration.enabled_calendar_ids.presence || ['primary']
    events = if enabled_ids.size == 1
               calendar_service.list_events(calendar_id: enabled_ids.first, time_min: time_min, time_max: time_max)
                               .map { |e| e.merge('calendarId' => enabled_ids.first) }
             else
               calendar_service.list_events_for_calendars(calendar_ids: enabled_ids, time_min: time_min, time_max: time_max)
             end
    render json: { events: events, google_email: @integration.google_email }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    target_calendar = schedule_target_calendar
    return if performed?

    event = calendar_service.create_event(
      calendar_id: target_calendar,
      summary:     params[:summary],
      description: params[:description],
      attendees:   Array(params[:attendees]),
      all_day:     params[:all_day].in?([true, 'true', '1']),
      start_time:  params[:start_time].present? ? Time.parse(params[:start_time]) : nil,
      end_time:    params[:end_time].present? ? Time.parse(params[:end_time]) : nil,
      due_date:    params[:due_date],
      end_date:    params[:end_date]
    )
    render json: { event: event }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    event = calendar_service.update_event(
      params[:id],
      calendar_id: params[:calendar_id].presence || 'primary',
      start_time:  Time.parse(params[:start_time]),
      end_time:    Time.parse(params[:end_time]),
      summary:     params[:summary],
      description: params[:description],
      attendees:   params[:attendees].present? ? Array(params[:attendees]) : nil
    )
    render json: { event: event }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # fix/calendario_eliminar F1 — DELETE /google_calendar/events/:id?calendar_id=&scope=one|all&notify=
  # Solo eventos de Google sin tarea agendada (las tareas se cancelan). Ver GoogleCalendarEventDeleter.
  DELETE_STATUS = { 'linked_to_agenda_item' => :conflict, 'no_permission' => :forbidden }.freeze

  def destroy
    target = delete_target
    return if performed?

    result = GoogleCalendarEventDeleter.new(
      account: Current.account, user: current_user, service: calendar_service, event_id: params[:id], options: delete_options(target)
    ).call
    return render json: { deleted: true, scope: result.scope } if result.ok

    render json: { error: I18n.t("google_calendar_delete.#{result.reason}"), reason: result.reason },
           status: DELETE_STATUS.fetch(result.reason, :unprocessable_entity)
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def delete_options(target)
    target.merge(scope: params[:scope], notify: params[:notify].to_s != 'false')
  end

  # feat/ventana_evento_calendario F5 (D7) — con `agent_id` de un compañero se borra en SU
  # calendario, solo si me dio «Hacer cambios» (lo pregunta el guardián a Google).
  def delete_target
    agent_id = params[:agent_id].presence
    return { calendar_id: params[:calendar_id] } if agent_id.nil? || agent_id.to_i == current_user.id

    guard = GoogleCalendarScheduleGuard.new(account: Current.account, viewer: current_user, agent_id: agent_id).call
    return render(json: { error: guard.error }, status: :forbidden) && {} unless guard.ok?

    email = guard.coworker_integration.google_email
    { calendar_id: email, owner_email: email }
  end

  # F3b «Agendar a» (fix/calendario_google): con `agent_id` de un compañero, el evento va a SU
  # calendario principal, creado con MI conexión y solo si me dio «Hacer cambios» en Google.
  # Yo no quedo como invitado: no aparece en mi calendario.
  def schedule_target_calendar
    agent_id = params[:agent_id].presence
    return params[:calendar_id].presence || 'primary' if agent_id.nil? || agent_id.to_i == current_user.id

    guard = GoogleCalendarScheduleGuard.new(account: Current.account, viewer: current_user, agent_id: agent_id).call
    return guard.coworker_integration.google_email if guard.ok?

    render json: { error: guard.error }, status: :forbidden
    nil
  end

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  def calendar_service
    @calendar_service ||= GoogleCalendarService.new(@integration)
  end

  def time_min
    params[:start] ? Time.parse(params[:start]) : Time.current.beginning_of_week
  end

  def time_max
    params[:end] ? Time.parse(params[:end]) : Time.current.end_of_week
  end
end
