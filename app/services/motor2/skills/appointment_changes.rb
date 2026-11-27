# frozen_string_literal: true

# «Citas» — mover o cancelar una de sus citas (la que dice en «cita», si tiene varias: Motor2::Skills::AppointmentList).
# Mover o cancelar mueve o borra el evento de Google con espera (el turno sigue en su transacción). En «Probar», solo
# en la memoria. Lo incluye Motor2::Skills::Appointments.
module Motor2::Skills::AppointmentChanges
  private

  def move(from, which)
    entry, error = target(which)
    return error if error

    @moving = entry
    keep_for_move(entry)
    slot = free_slot(from)
    return slot if slot[:error]
    return moved_in_test(entry, slot) if entry['test']

    meeting = meeting_for(entry)
    reschedule(meeting, slot)
    { ok: true, cita: local(meeting.starts_at), con: meeting.organizer&.name }.compact
  end

  def moved_in_test(entry, slot)
    entry['at'] = local(slot[:slot])
    entry['with'] = slot[:agent_name]
    { ok: true, prueba: true, cita: entry['at'], con: entry['with'] }.compact
  end

  def reschedule(meeting, slot)
    meeting.update!(starts_at: slot[:slot], ends_at: slot[:end_time])
    # Con espera: el turno sigue en su transacción y el job leería la hora de antes.
    Cases::MeetingSyncJob.set(wait: SYNC_WAIT).perform_later(meeting.id, 'update', meeting.saved_changes.except('updated_at'))
    trace.event(:cita, "movida a #{local(slot[:slot])}")
    notice(meeting)
  end

  def cancel(reason, which)
    entry, error = target(which)
    return error if error
    return (entry['cancelled'] = true) && { ok: true, prueba: true, cita: entry_text(entry) } if entry['test']

    meeting = meeting_for(entry)
    meeting.update!(status: :cancelled, cancel_reason: reason.to_s.presence || 'El cliente la canceló')
    Cases::MeetingSyncJob.set(wait: SYNC_WAIT).perform_later(meeting.id, 'cancel')
    trace.event(:cita, 'cancelada')
    { ok: true, cita: entry_text(entry) }
  end

  # El recordatorio y el «¿otro horario?» si no llega (Motor2::AppointmentNotice), con la hora nueva.
  def notice(scheduled)
    tracking = @turn.tracking
    @turn.after_send { Motor2::AppointmentNotice.schedule!(tracking, scheduled) } if tracking
  end
end
