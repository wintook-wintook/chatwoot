class Api::V1::Accounts::GoogleCalendar::AvailabilityController < Api::V1::Accounts::BaseController
  def show
    integrations = UserCalendarIntegration.where(account: Current.account)
    integrations = integrations.where(user_id: params[:agent_ids]) if params[:agent_ids].present?

    availability = integrations.filter_map do |integration|
      service = GoogleCalendarService.new(integration)
      busy = service.free_busy(
        calendars: ['primary'],
        time_min: time_min,
        time_max: time_max
      )
      {
        agent_id:    integration.user_id,
        google_email: integration.google_email,
        busy:        busy.dig('calendars', 'primary', 'busy') || []
      }
    rescue StandardError => e
      Rails.logger.error "GoogleCalendar availability error for user #{integration.user_id}: #{e.message}"
      nil
    end

    render json: { availability: availability }
  end

  private

  def time_min
    params[:start] ? Time.parse(params[:start]) : Time.current.beginning_of_day
  end

  def time_max
    params[:end] ? Time.parse(params[:end]) : Time.current.end_of_day
  end
end
