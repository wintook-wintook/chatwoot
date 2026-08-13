# frozen_string_literal: true

# @tickets_cases F3 — Serialización de reuniones para la API.
# Vive fuera del controlador para que este se quede con el flujo (autorización,
# espejo y bitácora) y no con el mapeo de campos.
module CaseMeetingSerializer
  extend ActiveSupport::Concern

  private

  def meeting_json(meeting)
    {
      id: meeting.id,
      sequence: meeting.sequence,
      folio: meeting.folio,
      title: meeting.title,
      description: meeting.description,
      starts_at: meeting.starts_at,
      ends_at: meeting.ends_at,
      time_zone: meeting.time_zone,
      location: meeting.location,
      status: meeting.status,
      created_at: meeting.created_at
    }.merge(meeting_sync_json(meeting)).merge(meeting_links_json(meeting))
  end

  # Estado del espejo con Google (en F1 siempre `local_only`) + firmas derivadas.
  def meeting_sync_json(meeting)
    {
      meeting_url: meeting.meeting_url,
      sync_status: meeting.sync_status,
      sync_error: meeting.sync_error,
      held_at: meeting.held_at,
      held_by: ref_user(meeting.held_by),
      cancelled_at: meeting.cancelled_at,
      cancelled_by: ref_user(meeting.cancelled_by)
    }
  end

  # A quién y a qué está ligada la reunión.
  def meeting_links_json(meeting)
    {
      notify_client: meeting.notify_client,
      attendee_emails: meeting.attendee_emails,
      organizer: ref_user(meeting.organizer),
      case_task: ref_task(meeting.case_task),
      series: ref_series(meeting.case_meeting_series)
    }
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name }
  end

  def ref_task(task)
    return nil unless task

    # `due_at` viaja para que la fila pueda marcar la reunión que se pasa del
    # vencimiento de su tarea (plan §6; la señalización completa es F6).
    { id: task.id, sequence: task.sequence, title: task.title, due_at: task.due_at }
  end

  def ref_series(series)
    return nil unless series

    { id: series.id, sequence: series.sequence, folio: series.folio, title: series.title }
  end
end
