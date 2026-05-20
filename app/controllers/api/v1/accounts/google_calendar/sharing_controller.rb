class Api::V1::Accounts::GoogleCalendar::SharingController < Api::V1::Accounts::BaseController
  before_action :require_integration

  def create
    events = parse_events(params[:events])
    return render json: { error: 'events required' }, status: :bad_request if events.empty?
    return render json: { error: 'inbox_id required' }, status: :bad_request if params[:inbox_id].blank?
    return render json: { error: 'contact_ids required' }, status: :bad_request if Array(params[:contact_ids]).empty?

    GoogleCalendarAgendaShareService.new(
      account:     Current.account,
      agent:       current_user,
      inbox_id:    params[:inbox_id],
      contact_ids: Array(params[:contact_ids]),
      events:      events
    ).perform

    render json: { success: true }
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  def parse_events(raw)
    Array(raw).map do |e|
      {
        summary:    e[:summary],
        all_day:    e[:all_day].in?([true, 'true', '1']),
        start_date: e[:start_date],
        start_time: e[:start_time].present? ? Time.parse(e[:start_time]) : nil,
        end_time:   e[:end_time].present?   ? Time.parse(e[:end_time])   : nil
      }
    end
  end
end
