# frozen_string_literal: true

# Pasar una tarea a la agenda (tarea agendada, con día y hora) o una tarea agendada a tarea
# normal (sin hora). Lo que ya se trabajó no se pierde: los reportes de tiempo pasan al nuevo.
#
#   Cases::Conversion.new(task, user:).to_meeting(starts_at:, ends_at:, time_zone:, location:, ...)
#     → { meeting:, mode: 'converted' | 'linked' }
#   Cases::Conversion.new(meeting, user:).to_task(notify_client: true)
#     → { task:, mode: 'converted' | 'linked', notice: nil | { sent: } }
#
# Tarea → agendada: la tarea desaparece. Si no se puede quitar (del cliente, obligatoria o de la
# plantilla de la etapa, o ya con sesiones agendadas) se agenda una sesión ligada a ella y la
# tarea se queda (mode: linked).
# Agendada → tarea: se quita de la agenda y de Google. Si era la sesión de una tarea, no se
# crea otra: queda esa (mode: linked). De una serie solo esa vez (se cancela con el motivo, para
# que la serie siga igual). Solo si sigue pendiente y no se ha salido a la visita.
class Cases::Conversion
  class Error < StandardError; end

  MAX_ESTIMATED = 1440

  def initialize(item, user:)
    @item = item
    @user = user
  end

  # ¿La tarea puede desaparecer al agendarse? Si no, se agenda una sesión ligada a ella.
  def self.task_replaceable?(task)
    task_kind_replaceable?(task) && !task.case_meetings.active.exists? && !task.case_meeting_series.exists?
  end

  # Lo mismo sin consultar sus sesiones: para las listas (el servidor revisa lo demás al agendar).
  def self.task_kind_replaceable?(task)
    task.pending? && !task.for_client? && !task.required? && task.case_type_column_task_id.nil? &&
      task.documentation_for_column_id.nil?
  end

  def self.meeting_convertible?(meeting)
    meeting.scheduled? && !Cases::Cancellation.work_started?(meeting)
  end

  def to_meeting(attrs)
    attrs = attrs.to_h.symbolize_keys
    fail_with('task_not_open') unless @item.pending?
    fail_with('starts_at') if attrs[:starts_at].blank?

    # keep_task: «que la tarea se quede» — solo una sesión de trabajo ligada a ella.
    replace = !ActiveModel::Type::Boolean.new.cast(attrs[:keep_task]) && self.class.task_replaceable?(@item)
    meeting = nil
    ActiveRecord::Base.transaction do
      meeting = build_meeting(attrs, linked: !replace)
      meeting.save!
      if replace
        move_reports({ case_task_id: @item.id }, case_task_id: nil, case_meeting_id: meeting.id)
        @item.skip_activity = true
        @item.destroy!
      end
    end
    after_meeting(meeting, replace)
    { meeting: meeting, mode: replace ? 'converted' : 'linked' }
  end

  def to_task(notify_client: false)
    fail_with('meeting_not_open') unless self.class.meeting_convertible?(@item)

    task = @item.case_task
    ActiveRecord::Base.transaction do
      task ||= build_task.tap(&:save!)
      move_reports({ case_meeting_id: @item.id }, case_meeting_id: nil, case_task_id: task.id)
      remove_meeting
    end
    log(:to_task, title: task.title, task_id: task.id, sequence: task.sequence, starts_at: @item.starts_at)
    notice = Cases::MeetingClientNotice.call(@item, @user, 'conversion.client_message') if notify_client && @item.client_contact
    { task: task, mode: @item.case_task_id ? 'linked' : 'converted', notice: notice }
  end

  private

  def fail_with(key)
    raise Error, I18n.with_locale(@item.account.locale.presence || I18n.default_locale) { I18n.t("conversion.errors.#{key}") }
  end

  def build_meeting(attrs, linked:)
    task = @item
    CaseMeeting.new(
      account: task.account, case_ticket: task.case_ticket, case_task: (task if linked && task.case_ticket),
      **own_client(task), **meeting_fields(attrs, task),
      organizer_id: organizer_id(attrs[:organizer_id]) || task.assignee_id || @user&.id, sync_status: :pending
    )
  end

  # Lo que capturó el usuario; lo que no, sale de la tarea.
  def meeting_fields(attrs, task)
    bool = ActiveModel::Type::Boolean.new
    { title: attrs[:title].presence || task.title, description: attrs.fetch(:description, task.description),
      starts_at: attrs[:starts_at], ends_at: attrs[:ends_at].presence || default_end(attrs[:starts_at], task),
      time_zone: attrs[:time_zone], location: attrs[:location], is_visit: bool.cast(attrs[:is_visit]) || false,
      notify_client: attrs.key?(:notify_client) ? bool.cast(attrs[:notify_client]) : true,
      attendee_emails: Array(attrs[:attendee_emails]).compact_blank }
  end

  # Sin caso, el contacto u organización viajan con ella (con caso, el cliente es el del caso).
  def own_client(item)
    item.case_ticket ? {} : { contact: item.contact, organization: item.organization }
  end

  # Sin hora de fin: lo estimado de la tarea, o una hora.
  def default_end(starts_at, task)
    start = starts_at.is_a?(String) ? Time.zone.parse(starts_at) : starts_at
    start && (start + (task.estimated_minutes || 60).minutes)
  end

  def organizer_id(id)
    @item.account.users.where(id: id).pick(:id) if id.present?
  end

  def after_meeting(meeting, replaced)
    Cases::MeetingSyncJob.perform_later(meeting.id, 'create')
    log(replaced ? :to_meeting : :linked, title: meeting.title, meeting_id: meeting.id, folio: meeting.folio,
                                          starts_at: meeting.starts_at, sequence: @item.sequence)
  end

  # El tiempo ya reportado pasa al nuevo.
  def move_reports(where, attrs)
    TaskReport.where(where).find_each { |report| report.update!(attrs) }
  end

  def build_task
    meeting = @item
    CaseTask.new(account: meeting.account, case_ticket: meeting.case_ticket, title: meeting.title.first(255),
                 description: meeting.description, due_at: due_day(meeting), assignee_id: meeting.organizer_id || @user&.id,
                 requester: @user, estimated_minutes: estimated(meeting), skip_activity: true, **own_client(meeting))
  end

  # La tarea vence al final del día de la cita (en la zona de la cita): sin hora.
  def due_day(meeting)
    zone = ActiveSupport::TimeZone[meeting.time_zone.to_s] || Time.zone
    meeting.starts_at.in_time_zone(zone).end_of_day
  end

  def estimated(meeting)
    minutes = ((meeting.ends_at - meeting.starts_at) / 60).round
    minutes.clamp(1, MAX_ESTIMATED) if minutes.positive?
  end

  # De una serie: solo esta vez, cancelada con el motivo (la serie sigue igual). Suelta: se
  # quita la fila y su evento de Google.
  def remove_meeting
    if @item.case_meeting_series_id
      @item.update!(status: :cancelled, cancel_reason: I18n.t('conversion.reason'))
      Cases::MeetingSyncJob.perform_later(@item.id, 'cancel')
    else
      Cases::Meetings::GoogleMirrorService.new(@item).cancel if @item.google_event_id.present?
      @item.destroy!
    end
  end

  def log(direction, **payload)
    ticket = @item.case_ticket
    return unless ticket

    ticket.case_events.create!(account: ticket.account, event_type: :task_converted, origin: @user ? :agent : :system,
                               actor: @user, payload: payload.merge(direction: direction.to_s))
  rescue StandardError => e
    Rails.logger.error("[Cases::Conversion] bitácora: #{e.message}")
  end
end
