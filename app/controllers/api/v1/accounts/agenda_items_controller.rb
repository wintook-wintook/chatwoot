# frozen_string_literal: true

# ================================================================================
# Plan-Agenda — las tareas agendadas del calendario. Son las mismas de los casos
# (CaseMeeting, siempre con hora); aquí pueden ir solo con su contacto.
# GET    /agenda_items?start=&end=        mis tareas agendadas del rango
# GET    /agenda_items/cases?contact_id=&organization_id=   casos abiertos para ligar
# POST   /agenda_items                    alta (con google_event_id: desde ese evento)
# PATCH  /agenda_items/:id                editar o ligar a un caso
# DELETE /agenda_items/:id
# ================================================================================
class Api::V1::Accounts::AgendaItemsController < Api::V1::Accounts::BaseController
  include TaskReportGuard

  CASES_LIMIT = 50
  FROZEN_MSG = 'Ticket cerrado: no se puede modificar. Reábrelo si necesitas cambiarlo.'

  before_action :set_meeting, only: %i[update destroy]
  before_action :block_if_frozen, only: %i[update destroy]

  def index
    meetings = Current.account.case_meetings.where(organizer_id: current_user.id, starts_at: range)
                      .where.not(status: %i[cancelled rescheduled])
                      .includes(:contact, :organization, case_ticket: %i[contact organization])
    render json: { agenda_items: meetings.map { |m| item_json(m) } }
  end

  def cases
    filters = { contact_id: params[:contact_id], organization_id: params[:organization_id] }.compact_blank
    return render json: { cases: [] } if filters.empty?

    open_cases = account_case_tickets.where.not(status: CaseTicket::CLOSED_STATUSES)
    scope = filters.map { |field, value| open_cases.where(field => value) }.reduce(:or)
    render json: { cases: scope.order(created_at: :desc).limit(CASES_LIMIT).map { |t| ref_case(t) } }
  end

  def create
    ticket = find_ticket
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if ticket&.frozen_for_edit?

    meeting = AgendaItems::Creator.new(account: Current.account, user: current_user, attrs: create_attrs,
                                       client: client_for(ticket), organizer: find_assignee).call
    render json: { agenda_item: item_json(meeting) }, status: :created
  rescue AgendaItems::Creator::AlreadyLinked
    render json: { error: I18n.t('agenda_items.already_linked') }, status: :unprocessable_entity
  rescue AgendaItems::Creator::AllDayEvent
    render json: { error: I18n.t('agenda_items.all_day') }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    return link_to_case if params[:case_ticket_id].present?
    return if %w[held no_show].include?(params[:status].to_s) && missing_task_report?(@meeting)

    if @meeting.update(update_attrs)
      sync_meeting
      render json: { agenda_item: item_json(@meeting) }
    else
      render json: { error: @meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Cases::Meetings::GoogleMirrorService.new(@meeting).cancel if @meeting.google_event_id.present?
    @meeting.destroy
    head :no_content
  end

  private

  def range
    from = params[:start].present? ? Time.zone.parse(params[:start]) : Time.current.beginning_of_week
    to = params[:end].present? ? Time.zone.parse(params[:end]) : Time.current.end_of_week
    from..to
  end

  def set_meeting
    @meeting = Current.account.case_meetings.find(params[:id])
    render_access_denied if access_grant.own?(:agenda) && @meeting.organizer_id != current_user.id
  end

  def block_if_frozen
    render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @meeting.case_ticket&.frozen_for_edit?
  end

  def find_ticket
    account_case_tickets.find(params[:case_ticket_id]) if params[:case_ticket_id].present?
  end

  # Con caso el cliente sale del caso. Sin él, contacto u organización que pueda ver, o nada.
  def client_for(ticket)
    return { case_ticket: ticket } if ticket

    { contact: (visible_contacts.find(params[:contact_id]) if params[:contact_id].present?),
      organization: (Current.account.organizations.find(params[:organization_id]) if params[:organization_id].present?) }
  end

  # Por defecto, quien agenda.
  def find_assignee
    Current.account.users.find_by(id: params[:assignee_id])
  end

  def visible_contacts
    access_grant.contacts(Current.account.contacts)
  end

  def create_attrs
    params.permit(:title, :description, :starts_at, :ends_at, :location, :is_visit, :calendar_id, :google_event_id,
                  attendee_emails: []).to_h.symbolize_keys
  end

  def update_attrs
    attrs = params.permit(:title, :description, :starts_at, :ends_at, :location, :status, :contact_id)
    attrs.delete(:status) unless CaseMeeting.statuses.key?(attrs[:status].to_s)
    attrs.delete(:contact_id) if @meeting.case_ticket
    attrs[:contact_id] = visible_contacts.find(attrs[:contact_id]).id if attrs[:contact_id].present?
    attrs
  end

  def link_to_case
    ticket = account_case_tickets.find(params[:case_ticket_id])
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if ticket.frozen_for_edit?

    render json: { agenda_item: item_json(AgendaItems::Linker.new(@meeting, ticket, current_user).call) }
  end

  def sync_meeting
    if @meeting.saved_change_to_status? && @meeting.cancelled?
      Cases::MeetingSyncJob.perform_later(@meeting.id, 'cancel')
    elsif @meeting.saved_changes.except('updated_at', 'status').any?
      Cases::MeetingSyncJob.perform_later(@meeting.id, 'update', @meeting.saved_changes.except('updated_at'))
    end
  end

  def item_json(meeting)
    { id: meeting.id, title: meeting.title, description: meeting.description, status: meeting.status,
      start: meeting.starts_at, end: meeting.ends_at, location: meeting.location,
      google_event_id: meeting.google_event_id, google_calendar_id: meeting.google_calendar_id,
      contact: ref(meeting.client_contact), organization: ref(meeting.client_organization),
      case_ticket: meeting.case_ticket && ref_case(meeting.case_ticket) }
  end

  def ref(record)
    record&.slice(:id, :name)
  end

  def ref_case(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, contact_id: ticket.contact_id, organization_id: ticket.organization_id }
  end
end
