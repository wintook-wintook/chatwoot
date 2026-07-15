class Api::V1::Accounts::GoogleCalendar::CalendarsController < Api::V1::Accounts::BaseController
  before_action :require_integration

  def show
    calendars = calendar_service.list_calendars
    render json: { calendars: calendars, enabled_ids: @integration.enabled_calendar_ids.presence || [] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    enabled_ids = Array(params[:enabled_ids])
    @integration.update!(enabled_calendar_ids: enabled_ids)
    render json: { enabled_ids: @integration.enabled_calendar_ids }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def subscribe
    calendar_id = params[:calendar_id].to_s.strip
    return render json: { error: 'calendar_id is required' }, status: :bad_request if calendar_id.blank?

    calendar_service.subscribe_calendar(calendar_id)
    calendars = calendar_service.list_calendars
    render json: { calendars: calendars, enabled_ids: @integration.enabled_calendar_ids.presence || [] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create_calendar
    summary = params[:summary].to_s.strip
    return render json: { error: 'summary is required' }, status: :bad_request if summary.blank?

    created = calendar_service.create_calendar(
      summary,
      description: params[:description],
      time_zone: params[:time_zone]
    )
    apply_color(created['id'], params[:background_color])
    render_calendars
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_calendar
    calendar_id = params[:calendar_id].to_s.strip
    return render json: { error: 'calendar_id is required' }, status: :bad_request if calendar_id.blank?

    calendar_service.update_calendar(
      calendar_id,
      summary: params[:summary],
      description: params[:description],
      time_zone: params[:time_zone]
    )
    apply_color(calendar_id, params[:background_color])
    render_calendars
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def apply_color(calendar_id, background_color)
    return if calendar_id.blank? || background_color.blank?

    calendar_service.set_calendar_color(calendar_id, background_color)
  end

  def render_calendars
    calendars = calendar_service.list_calendars
    render json: { calendars: calendars, enabled_ids: @integration.enabled_calendar_ids.presence || [] }
  end

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  def calendar_service
    @calendar_service ||= GoogleCalendarService.new(@integration)
  end
end
