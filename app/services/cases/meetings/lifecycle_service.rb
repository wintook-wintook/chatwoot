# frozen_string_literal: true

# @tickets_cases F5 — Reuniones huérfanas al completar una tarea o cerrar el
# ticket (plan §11.2), y extensión de la serie al mover el vencimiento (§11.1).
#
# Dos responsabilidades, ninguna automática:
#   * `pending` — QUÉ reuniones quedarían huérfanas. La UI las muestra SIEMPRE
#     antes de tocar nada: no se cancela sin enseñarlas.
#   * `cancel!` — cancelarlas eligiendo la técnica que manda UN solo aviso:
#
#       ninguna ocurrencia realizada aún → DELETE del maestro        → 1 correo
#       serie ya empezada                → PATCH truncando el UNTIL  → 1 correo
#       reuniones sueltas                → PATCH instancia/evento    → 1 por cita
#
#     Cancelar ocurrencia por ocurrencia está prohibido: manda N correos.
#
# ⚠️ Cancelar NO es reversible: en Google es destructivo y el cliente ya recibió
# el aviso. Reabrir el ticket no resucita las reuniones. El diálogo lo dice.
class Cases::Meetings::LifecycleService
  # Defaults de la casilla según el estado destino (§11.2). `resolved` y
  # `validating` NO son terminales: la reunión futura puede ser justo la de
  # validación con el cliente, así que se ofrece DESMARCADA.
  CANCEL_DEFAULT_BY_STATUS = {
    'resolved' => false,
    'validating' => false,
    'closed' => true,
    'cancelled' => true
  }.freeze

  def self.cancel_default_for(status)
    CANCEL_DEFAULT_BY_STATUS.fetch(status.to_s, false)
  end

  def initialize(ticket, actor: nil)
    @ticket = ticket
    @actor = actor
  end

  # Reuniones que quedarían huérfanas. `case_task` limita el alcance a esa tarea
  # (completar una tarea no toca las reuniones de otras ni las del ticket suelto);
  # sin tarea, son las de todo el ticket. Solo futuras y solo `scheduled`.
  def pending(case_task: nil)
    scope = @ticket.case_meetings.active.where(starts_at: Time.current..)
    scope = scope.where(case_task_id: case_task.id) if case_task
    scope.order(:starts_at)
  end

  # Cancela las reuniones dadas con la técnica de menos correos. Devuelve cuántas
  # quedaron canceladas.
  def cancel!(meetings)
    meetings = Array(meetings)
    return 0 if meetings.empty?

    loose, in_series = meetings.partition { |m| m.case_meeting_series_id.blank? }
    cancelled = loose.count { |m| cancel_one(m) }
    in_series.group_by(&:case_meeting_series_id).each do |series_id, group|
      cancelled += cancel_series_group(CaseMeetingSeries.find_by(id: series_id), group)
    end
    cancelled
  end

  # §11.1 — el vencimiento de la tarea se movió: extender la serie hasta la fecha
  # nueva. NUNCA se hace solo (cada ocurrencia nueva le escribe al cliente): lo
  # dispara la casilla del diálogo de la tarea.
  def extend_series_to(series, new_due_at)
    return 0 if series.blank? || new_due_at.blank?

    before = series.case_meetings.count
    series.update!(until_at: new_due_at, count: nil)
    Cases::Meetings::SeriesService.new(series, actor: @actor).regenerate_missing!
    series.case_meetings.count - before
  end

  private

  def cancel_one(meeting)
    meeting.update!(status: :cancelled)
    Cases::MeetingSyncJob.perform_later(meeting.id, 'cancel')
    log_cancel(meeting, scope: 'one')
    true
  end

  # Un grupo de ocurrencias de la MISMA serie: o se borra el maestro (si no hay
  # nada realizado) o se trunca (si la serie ya empezó). En ambos casos, 1 aviso.
  def cancel_series_group(series, group)
    return group.count { |m| cancel_one(m) } if series.nil?

    kept = last_kept_occurrence(series, group)
    if kept.nil?
      Cases::Meetings::GoogleMirrorService.new(group.first).cancel_series(series)
      group.each { |m| m.update!(status: :cancelled) }
      series.cancel!(actor: @actor)
      log_cancel(group.first, scope: 'all')
      return group.size
    end

    dropped = Cases::Meetings::SeriesService.new(series, actor: @actor).truncate!(kept.starts_at)
    log_cancel(group.first, scope: 'all')
    dropped
  end

  # Última ocurrencia que NO se cancela: la más reciente ya realizada o pasada.
  # nil = la serie no ha empezado, así que se puede borrar el maestro entero.
  def last_kept_occurrence(series, group)
    series.case_meetings
          .where.not(id: group.map(&:id))
          .where('starts_at < ? OR status IN (?)', Time.current,
                 [CaseMeeting.statuses[:held], CaseMeeting.statuses[:no_show]])
          .order(:starts_at)
          .last
  end

  def log_cancel(meeting, scope:)
    @ticket.case_events.create!(
      account_id: @ticket.account_id,
      event_type: :meeting_cancelled,
      origin: @actor ? :agent : :system,
      actor: @actor,
      case_task: meeting.case_task,
      payload: {
        meeting_id: meeting.id, folio: meeting.folio, title: meeting.title,
        starts_at: meeting.starts_at, scope: scope, source: 'lifecycle'
      }
    )
  end
end
