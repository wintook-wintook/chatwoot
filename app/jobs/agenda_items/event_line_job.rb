# Plan-Agenda A2 — pone en el evento de Google la línea hacia su tarea agendada (sin
# invitados). Solo la descripción: no mueve el evento ni avisa a nadie.
class AgendaItems::EventLineJob < ApplicationJob
  queue_as :low

  def perform(meeting_id)
    meeting = CaseMeeting.find_by(id: meeting_id)
    return if meeting.nil? || meeting.google_event_id.blank?

    integration = UserCalendarIntegration.find_by(account_id: meeting.account_id, user_id: meeting.organizer_id)
    return if integration.nil?

    # Abre el canal de avisos también para quien nunca agendó desde un caso.
    Cases::Meetings::PushChannelService.new(integration).ensure_channel!
    return if meeting.attendee_emails.present?

    GoogleCalendarService.new(integration).set_description(meeting.google_event_id, calendar_id: meeting.google_calendar_id.presence || 'primary',
                                                                                    description: AgendaItems::EventLine.description_for(meeting))
  rescue StandardError => e
    Rails.logger.error("[Agenda] EventLineJob #{meeting_id}: #{e.message}")
  end
end
