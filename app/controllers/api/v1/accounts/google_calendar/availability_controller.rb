# Franjas de «ocupado» de los agentes de la cuenta para el calendario.
# fix/calendario_google (D1): se consulta con la conexión de QUIEN MIRA, así que solo salen los
# compañeros que le compartieron al menos «Solo libre/ocupado». Antes se usaba la conexión de
# cada compañero y se veía el ocupado de todos aunque nadie hubiera compartido nada.
class Api::V1::Accounts::GoogleCalendar::AvailabilityController < Api::V1::Accounts::BaseController
  VISIBLE_ACCESS = %w[details free_busy].freeze

  def show
    viewer = current_user.user_calendar_integrations.find_by(account: Current.account)
    return render json: { availability: [] } unless viewer

    viewer_service = GoogleCalendarService.new(viewer)
    render json: { availability: [own_row(viewer, viewer_service)].compact + coworker_rows(viewer, viewer_service) }
  rescue StandardError => e
    Rails.logger.error "GoogleCalendar availability error for user #{current_user.id}: #{e.message}"
    render json: { availability: [] }
  end

  private

  def integrations
    scope = UserCalendarIntegration.where(account: Current.account)
    params[:agent_ids].present? ? scope.where(user_id: params[:agent_ids]) : scope
  end

  def own_row(viewer, viewer_service)
    return nil if params[:agent_ids].present? && Array(params[:agent_ids]).map(&:to_i).exclude?(viewer.user_id)

    busy = viewer_service.free_busy(calendars: ['primary'], time_min: time_min, time_max: time_max)
    { agent_id: viewer.user_id, busy: busy.dig('calendars', 'primary', 'busy') || [] }
  rescue StandardError => e
    Rails.logger.warn "GoogleCalendar own availability error for user #{viewer.user_id}: #{e.message}"
    nil
  end

  def coworker_rows(viewer, viewer_service)
    coworkers = integrations.where.not(user_id: viewer.user_id).to_a
    GoogleCalendarCoworkerService.new(viewer_integration: viewer, viewer_service: viewer_service)
                                 .fetch_many(coworkers, time_min: time_min, time_max: time_max)
                                 .select { |r| VISIBLE_ACCESS.include?(r[:access]) }
                                 .map { |r| { agent_id: r[:agent_id], busy: busy_blocks(r[:events]) } }
  end

  def busy_blocks(events)
    events.reject { |e| e[:all_day] }.map { |e| { start: e[:start], end: e[:end] } }
  end

  def time_min
    params[:start] ? Time.zone.parse(params[:start]) : Time.current.beginning_of_day
  end

  def time_max
    params[:end] ? Time.zone.parse(params[:end]) : Time.current.end_of_day
  end
end
