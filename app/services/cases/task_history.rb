# frozen_string_literal: true

# Historial de una tarea: todo lo que pasó con ella en una sola lista, de lo más nuevo a lo
# más viejo, con el mismo formato que la actividad del caso (Cases::ActivityFeed):
#   • con caso: sus movimientos en la bitácora (case_task_id), los de sus tareas agendadas
#     (payload meeting_id) y los reportes de esas agendadas;
#   • sin caso (tarea rápida): se arma con sus registros (creada, reportes, agendadas,
#     completada o cancelada), porque no tiene bitácora.
# Los reportes llevan su detalle (tiempo, resultado, evidencia) en `report`.
#   Cases::TaskHistory.new(task, zone:, file_url: ->(file) { … }).call → { task: {...}, items: [...] }
class Cases::TaskHistory
  def initialize(task, zone: nil, file_url: nil)
    @task = task
    @ticket = task.case_ticket
    @zone = zone || Time.zone
    @file_url = file_url
  end

  def call
    items = @ticket ? case_items : quick_items
    items << created_item unless items.any? { |i| i[:event_type] == 'task_created' }
    { task: summary, items: items.sort_by { |i| -i[:at].to_f } }
  end

  private

  def meetings
    @meetings ||= @task.case_meetings.order(:starts_at).to_a
  end

  def reports
    @reports ||= TaskReport.closed.where(case_task_id: @task.id)
                           .or(TaskReport.closed.where(case_meeting_id: meetings.map(&:id)))
                           .includes(:user, :case_meeting).with_attached_evidence.index_by(&:id)
  end

  # --- con caso: la bitácora --------------------------------------------------------
  def case_items
    events = @ticket.case_events.includes(:actor)
    scope = events.where(case_task_id: @task.id)
    scope = scope.or(events.where("case_events.payload->>'meeting_id' IN (?)", meetings.map { |m| m.id.to_s })) if meetings.any?
    report_ids = reports.values.select(&:case_meeting_id).map { |r| r.id.to_s }
    scope = scope.or(events.where(event_type: :task_reported).where("case_events.payload->>'task_report_id' IN (?)", report_ids)) if report_ids.any?
    scope.map { |event| event_item(event) }
  end

  def event_item(event)
    item = { kind: 'event', id: event.id, at: event.created_at, event_type: event.event_type, origin: event.origin,
             payload: event.payload, actor: user_ref(event.actor) }
    report = reports[event.payload['task_report_id'].to_i] if event.task_reported?
    report ? item.merge(report: report_detail(report)) : item
  end

  # --- sin caso: de sus registros ------------------------------------------------------
  def quick_items
    reports.values.map { |r| report_item(r) } + meetings.flat_map { |m| meeting_items(m) } + closing_items
  end

  def report_item(report)
    kind = report.progress? ? 'progress' : 'task_report'
    synthetic("report-#{report.id}", report.created_at, 'task_reported', report.user,
              { kind: kind, title: report.title, content: report.content, minutes: report.minutes, sequence: @task.sequence })
      .merge(report: report_detail(report))
  end

  def meeting_items(meeting)
    payload = { meeting_id: meeting.id, folio: meeting.folio, title: meeting.title, starts_at: meeting.starts_at }
    list = [synthetic("meeting-#{meeting.id}", meeting.created_at, 'meeting_scheduled', meeting.organizer, payload)]
    if meeting.held? || meeting.no_show?
      list << synthetic("meeting-held-#{meeting.id}", meeting.held_at || meeting.updated_at, 'meeting_held', nil,
                        payload.merge(status: meeting.status))
    end
    if meeting.cancelled?
      list << synthetic("meeting-cancel-#{meeting.id}", meeting.cancelled_at || meeting.updated_at, 'meeting_cancelled', nil,
                        payload.merge(reason: meeting.cancel_reason))
    end
    list
  end

  def closing_items
    base = { sequence: @task.sequence, title: @task.title }
    list = []
    list << synthetic('done', @task.completed_at, 'task_completed', @task.completed_by, base) if @task.done? && @task.completed_at
    if @task.cancelled? && @task.cancelled_at
      list << synthetic('cancelled', @task.cancelled_at, 'task_cancelled', nil, base.merge(reason: @task.cancel_reason))
    end
    list
  end

  def created_item
    synthetic('created', @task.created_at, 'task_created', @task.requester, { sequence: @task.sequence, title: @task.title })
  end

  def synthetic(key, at, type, actor, payload)
    { kind: 'event', id: "t#{@task.id}-#{key}", at: at, event_type: type, origin: actor ? 'agent' : 'system',
      payload: payload.compact.stringify_keys, actor: user_ref(actor) }
  end

  # --- detalle --------------------------------------------------------------------------
  def report_detail(report)
    { id: report.id, content: report.content, minutes: report.minutes, outcome: report.outcome_label, progress: report.progress?,
      meeting: report.case_meeting&.slice(:id, :title),
      evidence: @file_url ? report.evidence.map { |file| { name: file.filename.to_s, url: @file_url.call(file) } } : [] }
  end

  def summary
    @task.slice(:id, :sequence, :title, :description, :status, :audience, :due_at, :planned_on, :estimated_minutes, :cancel_reason)
         .merge(reported_minutes: reports.values.select(&:case_task_id).sum { |r| r.minutes.to_i },
                assignee: user_ref(@task.assignee), requester: user_ref(@task.requester))
         .merge(client_summary)
  end

  def client_summary
    { case: @ticket&.slice(:id, :folio, :title, :status), contact: client_contact&.slice(:id, :name),
      organization: client_organization&.slice(:id, :name),
      meetings: meetings.map { |m| { id: m.id, folio: m.folio, title: m.title, starts_at: m.starts_at, status: m.status } } }
  end

  def client_contact = @ticket ? @ticket.contact : @task.contact
  def client_organization = @ticket ? @ticket.organization : @task.organization

  def user_ref(user)
    user && { id: user.id, name: user.name }
  end
end
