# frozen_string_literal: true

# Motor 2.0 — el recordatorio de la cita o el «¿te agendo otro horario?» si no llegó (Motor2::AppointmentNotice).
class Motor2::AppointmentNoticeJob < ApplicationJob
  queue_as :default

  def perform(tracking_id, meeting_id, kind, stamp)
    tracking = ContactTracking.find_by(id: tracking_id)
    meeting = CaseMeeting.find_by(id: meeting_id)
    return unless tracking&.conversation && Motor2::AppointmentNotice.due?(meeting, kind, stamp)

    Motor2::AppointmentNotice.deliver(tracking, meeting, kind)
  end
end
