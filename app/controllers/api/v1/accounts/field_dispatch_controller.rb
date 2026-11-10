# Plan-Trabajo-Campo R3 — despacho de órdenes en campo.
#
#   GET  /field_dispatch?day=YYYY-MM-DD
#   POST /field_dispatch/assign  { order_id, user_id, meeting_id?, starts_at?, duration_minutes? }
#        asigna la orden al técnico; con `meeting_id` mueve esa visita a él (y de hora si
#        viene `starts_at`); sin visita y con `starts_at`, la agenda.
#   POST /field_dispatch/move_visit  { meeting_id, user_id, starts_at? }
#        cambia de persona o de hora una visita sin orden de trabajo.
#
# Lo usa quien despacha: ve todo Servicio o Ventas y puede asignar a otra persona.
class Api::V1::Accounts::FieldDispatchController < Api::V1::Accounts::BaseController
  DEFAULT_MINUTES = 60
  DISPATCH_AREAS = %i[service sales].freeze
  FULL_LEVELS = %w[all view].freeze

  before_action :check_dispatcher

  def show
    render json: board
  end

  def assign
    order = account_case_tickets.find(params[:order_id])
    user = Current.account.users.find(params[:user_id])
    CaseTicket.transaction do
      order.update!(assignee: user, assignee_type: :agent)
      schedule!(order, user)
    end
    render json: board
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('service_reports.errors.not_found') }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def move_visit
    meeting = Current.account.case_meetings.where(is_visit: true).find(params[:meeting_id])
    Field::VisitMover.new(meeting, Current.account.users.find(params[:user_id]), new_start).call
    render json: board
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('service_reports.errors.not_found') }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  private

  def check_dispatcher
    return if access_grant.admin?
    return if access_grant.can?(:reassign) && DISPATCH_AREAS.any? { |area| FULL_LEVELS.include?(access_grant.level(area)) }

    render_access_denied
  end

  def board
    Field::DispatchBoard.new(Current.account, account_case_tickets, day, ActiveSupport::TimeZone[params[:tz].to_s] || Time.zone).build
  end

  def new_start
    Time.zone.parse(params[:starts_at].to_s) if params[:starts_at].present?
  end

  def day
    Date.parse(params[:day].to_s)
  rescue Date::Error
    Time.zone.today
  end

  def schedule!(order, user)
    meeting = order.case_meetings.find_by(id: params[:meeting_id]) if params[:meeting_id].present?
    starts_at = Time.zone.parse(params[:starts_at].to_s) if params[:starts_at].present?
    return move_meeting(meeting, user, starts_at) if meeting
    return unless starts_at

    minutes = (params[:duration_minutes].presence || DEFAULT_MINUTES).to_i
    created = order.case_meetings.create!(account: order.account, title: order.title.truncate(120), organizer: user,
                                          starts_at: starts_at, ends_at: starts_at + minutes.minutes)
    Cases::MeetingSyncJob.perform_later(created.id, 'create')
  end

  def move_meeting(meeting, user, starts_at)
    changes = { organizer: user }
    if starts_at
      length = (meeting.ends_at || meeting.starts_at) - meeting.starts_at
      changes.merge!(starts_at: starts_at, ends_at: starts_at + length)
    end
    meeting.update!(changes)
    Cases::MeetingSyncJob.perform_later(meeting.id, 'update', meeting.saved_changes.except('updated_at'))
  end
end
