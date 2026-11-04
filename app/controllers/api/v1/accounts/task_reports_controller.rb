# frozen_string_literal: true

# ================================================================================
# Reporte de cierre.
# POST /task_reports  (multipart) { item_type: task|meeting, item_id, content,
#                                   task_outcome_id, evidence[] }
#   Se manda ANTES de concluir; se cierra solo cuando la tarea de verdad se concluye.
# POST /task_reports  (multipart) { item_type: activity, title, content, done_at,
#                                   case_ticket_id | contact_id | organization_id, ... }
#   Actividad reportada: algo que se hizo sin tarea. Nace cerrada; con caso entra a
#   su actividad. Sin cliente es interna (solo en Reportes).
# GET  /task_reports  { contact_id, organization_id, user_id, case_task_id,
#                       case_meeting_id, from, to, page }
#   Con Agenda en «solo lo suyo», solo los propios. meta: total de minutos y por persona.
# GET  /task_reports/suggestion { item_type, item_id } → tiempo propuesto y si es
#   obligatorio. `minutes` (tiempo dedicado) va en los dos POST; con caso, al cerrar
#   suma a las horas reales del caso (TaskReport#log_time).
# ================================================================================
class Api::V1::Accounts::TaskReportsController < Api::V1::Accounts::BaseController
  PER_PAGE = 25
  FILTERS = %i[contact_id organization_id user_id case_task_id case_meeting_id].freeze

  def index
    scope = filtered(Current.account.task_reports.closed)
    rows = scope.includes(:user, :contact, :organization, :case_ticket, :case_task, :case_meeting, :case_time_entry).with_attached_evidence
                .order(created_at: :desc).limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    render json: { task_reports: rows.map { |r| report_json(r) }, meta: list_meta(scope) }
  end

  def suggestion
    minutes = params[:item_type] == 'activity' ? nil : TaskReport.suggested_minutes(find_item)
    render json: { minutes: minutes, required: TaskReport.minutes_required?(Current.account) }
  end

  def create
    return render_minutes_required if missing_minutes?
    return create_activity if params[:item_type] == 'activity'

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

  def create_activity
    at = done_at # las listas ordenan y filtran por created_at: va la hora en que se hizo
    report = Current.account.task_reports.new(report_attrs.merge(activity_client)
                                                          .merge(title: params[:title].to_s.strip, created_at: at))
    TaskReport.transaction do
      report.save!
      report.close!(at)
    end
    render json: { task_report: report_json(report) }, status: :created
  rescue ActiveRecord::RecordNotFound
    render_access_denied
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # Con caso, el cliente es el del caso; con contacto, también su organización (así
  # sale en la ficha de la organización). Todo dentro de lo que la persona puede ver.
  def activity_client
    if params[:case_ticket_id].present?
      ticket = account_case_tickets.find(params[:case_ticket_id])
      return { case_ticket: ticket, contact: ticket.contact, organization: ticket.organization }
    end

    contact = activity_contact
    organization = Current.account.organizations.find(params[:organization_id]) if params[:organization_id].present?
    { contact: contact, organization: organization || contact&.organization }
  end

  def activity_contact
    access_grant.contacts(Current.account.contacts).find(params[:contact_id]) if params[:contact_id].present?
  end

  # Cuándo se hizo: por omisión ahora; nunca en el futuro.
  def done_at
    at = Time.zone.parse(params[:done_at].to_s) if params[:done_at].present?
    at && at < Time.current ? at : Time.current
  rescue ArgumentError
    Time.current
  end

  def page
    [params[:page].to_i, 1].max
  end

  def list_meta(scope)
    by_user = scope.where.not(minutes: nil).group(:user_id).sum(:minutes)
    names = Current.account.users.where(id: by_user.keys).pluck(:id, :name).to_h
    { count: scope.count, page: page, per_page: PER_PAGE, total_minutes: by_user.values.sum,
      by_user: by_user.map { |id, minutes| { id: id, name: names[id], minutes: minutes } }.sort_by { |row| -row[:minutes] } }
  end

  def minutes_param
    value = params[:minutes].presence
    value && Integer(value.to_s, exception: false)
  end

  def missing_minutes?
    TaskReport.minutes_required?(Current.account) && !minutes_param.to_i.positive?
  end

  def render_minutes_required
    render json: { error: I18n.t('task_reports.minutes_required'), minutes_required: true }, status: :unprocessable_entity
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
      minutes: minutes_param, evidence: Array(params[:evidence]).compact_blank }
  end

  def report_json(report)
    { id: report.id, title: report.title, content: report.content, outcome: report.outcome_label, created_at: report.created_at,
      minutes: report.minutes, estimated_minutes: report.case_task&.estimated_minutes,
      kind: report_kind(report), user: report_user(report), contact: report.contact&.slice(:id, :name),
      organization: report.organization&.slice(:id, :name), case_ticket: report.case_ticket&.slice(:id, :folio, :title),
      evidence: report.evidence.map { |file| evidence_json(file) } }
      .merge(arrival: arrival_json(report), service_report_url: service_report_url(report))
  end

  def report_kind(report)
    return 'order' if report.case_time_entry_id
    return 'activity' if report.activity?

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
