# frozen_string_literal: true

# ================================================================================
# Reporte de cierre.
# POST /task_reports  (multipart) { item_type: task|meeting, item_id, content,
#                                   task_outcome_id, evidence[] }
#   Se manda ANTES de concluir; se cierra solo cuando la tarea de verdad se concluye.
# GET  /task_reports  { contact_id, organization_id, user_id, case_task_id,
#                       case_meeting_id, from, to, page }
#   Con Agenda en «solo lo suyo», solo los propios.
# ================================================================================
class Api::V1::Accounts::TaskReportsController < Api::V1::Accounts::BaseController
  PER_PAGE = 25
  FILTERS = %i[contact_id organization_id user_id case_task_id case_meeting_id].freeze

  def index
    scope = filtered(Current.account.task_reports.closed)
    rows = scope.includes(:user, :contact, :organization, :case_ticket, :case_meeting, :case_time_entry).with_attached_evidence
                .order(created_at: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    render json: { task_reports: rows.map { |r| report_json(r) }, meta: { count: scope.count, page: page, per_page: PER_PAGE } }
  end

  def create
    item = find_item
    return render_access_denied unless reportable?(item)

    report = TaskReport.build_for(item, report_attrs)
    TaskReport.transaction do
      item.task_reports.pending_close.destroy_all # reintento: manda el último
      report.save!
    end
    render json: { task_report: report_json(report) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def page
    [params[:page].to_i, 1].max
  end

  def filtered(scope)
    scope = scope.where(params.permit(*FILTERS).to_h.compact_blank)
    scope = in_dates(scope)
    see_all? ? scope : scope.where(user_id: current_user.id)
  end

  def in_dates(scope)
    scope = scope.where(created_at: Time.zone.parse(params[:from])..) if params[:from].present?
    scope = scope.where(created_at: ..Time.zone.parse(params[:to]).end_of_day) if params[:to].present?
    scope
  end

  def see_all?
    access_grant.admin? || %w[all view].include?(access_grant.level(:agenda))
  end

  def find_item
    (params[:item_type] == 'meeting' ? Current.account.case_meetings : Current.account.case_tasks).find(params[:item_id])
  end

  def reportable?(item)
    return true if [item.try(:assignee_id), item.try(:requester_id), item.try(:organizer_id)].include?(current_user.id)
    return account_case_tickets.exists?(id: item.case_ticket_id) if item.case_ticket_id

    !access_grant.own?(:agenda)
  end

  def report_attrs
    outcome = Current.account.task_outcomes.find_by(id: params[:task_outcome_id])
    { user: current_user, content: params[:content].to_s.strip, task_outcome: outcome, outcome_label: outcome&.label,
      evidence: Array(params[:evidence]).compact_blank }
  end

  def report_json(report)
    { id: report.id, title: report.title, content: report.content, outcome: report.outcome_label, created_at: report.created_at,
      kind: report_kind(report), user: report_user(report), contact: report.contact&.slice(:id, :name),
      organization: report.organization&.slice(:id, :name), case_ticket: report.case_ticket&.slice(:id, :folio, :title),
      evidence: report.evidence.map { |file| evidence_json(file) } }
      .merge(arrival: arrival_json(report), service_report_url: service_report_url(report))
  end

  def report_kind(report)
    return 'order' if report.case_time_entry_id

    report.case_meeting_id ? 'meeting' : 'task'
  end

  # El técnico externo no tiene usuario: su nombre quedó en la entrada de horas.
  def report_user(report)
    report.user&.slice(:id, :name) || (report.case_time_entry&.note && { name: report.case_time_entry.note })
  end

  # La llegada de la visita, si la tuvo; puede no traer ubicación.
  def arrival_json(report)
    entry = report.case_time_entry
    return entry.location.fetch('arrive', {}).slice('lat', 'lng').merge(at: entry.started_at) if entry

    meeting = report.case_meeting
    meeting.arrival_location.slice('lat', 'lng').merge(at: meeting.arrived_at) if meeting&.arrived_at
  end

  def service_report_url(report)
    ServiceReports::Delivery.public_url(report.case_ticket) if report.case_time_entry_id && report.case_ticket
  end

  def evidence_json(file)
    { id: file.id, name: file.filename.to_s, url: url_for(file) }
  end
end
