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

  private

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  def calendar_service
    @calendar_service ||= GoogleCalendarService.new(@integration)
  end
end
