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
    event = calendar_service.create_event(
      calendar_id: params[:calendar_id].presence || 'primary',
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

  def agent_events
    agent_integration = UserCalendarIntegration.find_by(
      user_id: params[:agent_id],
      account: Current.account
    )
    return render json: { error: 'Agent not connected' }, status: :not_found unless agent_integration

    service = GoogleCalendarService.new(agent_integration)

    if params[:agent_id].to_s == current_user.id.to_s
      events = service.list_events(time_min: time_min, time_max: time_max)
      render json: { events: events }
    else
      busy = service.free_busy(
        calendars: ['primary'],
        time_min: time_min,
        time_max: time_max
      )
      render json: { busy: busy.dig('calendars', 'primary', 'busy') || [] }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

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
