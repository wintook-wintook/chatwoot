# Plan-Trabajo-Campo R3 — despacho de órdenes en campo.
#
#   GET  /field_dispatch?day=YYYY-MM-DD
#   POST /field_dispatch/assign  { order_id, user_id, meeting_id?, starts_at?, duration_minutes? }
#        asigna la orden al técnico; con `meeting_id` mueve esa visita a él (y de hora si
#        viene `starts_at`); sin visita y con `starts_at`, la agenda.
#
# Lo usa quien despacha: ve todo Servicio y puede asignar a otra persona.
class Api::V1::Accounts::FieldDispatchController < Api::V1::Accounts::BaseController
  DEFAULT_MINUTES = 60

  before_action :check_dispatcher

  def show
    render json: Field::DispatchBoard.new(Current.account, account_case_tickets, day).build
  end

  def assign
    order = account_case_tickets.find(params[:order_id])
    user = Current.account.users.find(params[:user_id])
    CaseTicket.transaction do
      order.update!(assignee: user, assignee_type: :agent)
      schedule!(order, user)
    end
    render json: Field::DispatchBoard.new(Current.account, account_case_tickets, day).build
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('service_reports.errors.not_found') }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  private

  def check_dispatcher
    return if access_grant.admin?
    return if access_grant.can?(:reassign) && %w[all view].include?(access_grant.level(:service))

    render_access_denied
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
