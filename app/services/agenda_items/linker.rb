# Plan-Agenda A2 — ligar a un caso la tarea agendada que estaba solo con su contacto: entra
# al caso con su folio y su lugar en la bitácora, y su evento de Google sigue siendo el mismo.
class AgendaItems::Linker
  def self.meeting_added(meeting, user)
    ticket = meeting.case_ticket
    return if ticket.nil?

    ticket.case_events.create!(account_id: meeting.account_id, event_type: :meeting_scheduled, origin: :agent, actor: user,
                               payload: { meeting_id: meeting.id, sequence: meeting.sequence, folio: meeting.folio,
                                          title: meeting.title, starts_at: meeting.starts_at, status: meeting.status, scope: 'one' })
    ticket.mark_visit_scheduled! if ticket.work_order?
  end

  def initialize(meeting, ticket, user)
    @meeting = meeting
    @ticket = ticket
    @user = user
  end

  def call
    @meeting.update!(case_ticket: @ticket, sequence: (@ticket.case_meetings.maximum(:sequence) || 0) + 1)
    self.class.meeting_added(@meeting, @user)
    AgendaItems::EventLineJob.perform_later(@meeting.id) if @meeting.google_event_id.present?
    @meeting
  end
end
