# Calendario de los compañeros de la cuenta (fix/calendario_google, F2).
# Todo se consulta con la conexión de Google de QUIEN MIRA (GoogleCalendarCoworkerService):
# Google solo entrega lo que cada compañero compartió. No se expone el correo de los compañeros.
class Api::V1::Accounts::GoogleCalendar::CoworkersController < Api::V1::Accounts::BaseController
  before_action :require_integration
  before_action :build_coworker_service

  # GET /google_calendar/coworkers
  # Estado de cada compañero de la cuenta (para el panel «Compañeros» y «Agendar a»).
  def index
    now = Time.current
    rows = coworker_users.map do |user|
      integration = integrations_by_user[user.id]
      next status_row(user.id, 'not_connected') unless integration

      result = @coworker_service.fetch(integration, time_min: now.beginning_of_day, time_max: now.end_of_day)
      status_row(user.id, result[:access], can_schedule: result[:can_schedule], busy_now: busy_at?(result[:events], now))
    end
    render json: { coworkers: rows, google_email: @integration.google_email }
  end

  # GET /google_calendar/coworkers/events?agent_ids[]=&start=&end=
  # Eventos de los compañeros palomeados, ya recortados por Google según lo compartido.
  def events
    ids = Array(params[:agent_ids]).map(&:to_i) & coworker_users.map(&:id)
    integrations = integrations_by_user.values_at(*ids).compact
    results = @coworker_service.fetch_many(integrations, time_min: time_min, time_max: time_max)
    render json: { coworkers: with_agenda_items(results).map { |r| r.except(:google_email) } }
  end

  private

  # feat/ventana_evento_calendario F5 — si el evento del compañero es una tarea agendada (sigue
  # agendada), lo mínimo para «Cancelar tarea agendada» con la ventana de motivo.
  def with_agenda_items(results)
    ids = results.flat_map { |r| Array(r[:events]).pluck(:id) }
    meetings = Current.account.case_meetings.scheduled.where(google_event_id: ids).index_by(&:google_event_id)
    return results if meetings.empty?

    results.map do |r|
      r.merge(events: Array(r[:events]).map { |e| meetings[e[:id]] ? e.merge(agenda_item: agenda_item_ref(meetings[e[:id]])) : e })
    end
  end

  def agenda_item_ref(meeting)
    { id: meeting.id, title: meeting.title, series: meeting.case_meeting_series_id.present?,
      work_started: Cases::Cancellation.work_started?(meeting),
      has_client: (meeting.client_contact || meeting.client_organization || meeting.case_ticket).present? }
  end

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  # Si el permiso de Google de quien mira venció, no hay nada que consultar: pedir reconectar.
  def build_coworker_service
    @coworker_service = GoogleCalendarCoworkerService.new(
      viewer_integration: @integration,
      viewer_service: GoogleCalendarService.new(@integration)
    )
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarCoworkers] user #{current_user.id}: #{e.message}"
    render json: { error: 'reconnect' }, status: :unprocessable_entity
  end

  def coworker_users
    @coworker_users ||= Current.account.users.where.not(id: current_user.id).order(:name).to_a
  end

  def integrations_by_user
    @integrations_by_user ||= UserCalendarIntegration.where(account: Current.account, user_id: coworker_users.map(&:id))
                                                     .index_by(&:user_id)
  end

  def status_row(agent_id, access, can_schedule: false, busy_now: false)
    { agent_id: agent_id, access: access, can_schedule: can_schedule, busy_now: busy_now }
  end

  # Ocupado ahora = algún evento con hora que cubre este momento (los de todo el día no cuentan).
  def busy_at?(events, now)
    events.any? do |e|
      next false if e[:all_day] || e[:start].blank? || e[:end].blank?

      Time.zone.parse(e[:start]) <= now && now < Time.zone.parse(e[:end])
    end
  end

  def time_min
    params[:start].present? ? Time.zone.parse(params[:start]) : Time.current.beginning_of_week
  end

  def time_max
    params[:end].present? ? Time.zone.parse(params[:end]) : Time.current.end_of_week
  end
end
