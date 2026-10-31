# Plan-Agenda A2 — la línea que, dentro de Google, dice que el evento tiene tarea agendada
# en Kontrolya. No va en eventos con invitados: el cliente vería una liga interna.
class AgendaItems::EventLine
  PREFIX = 'Tarea en Kontrolya: '.freeze

  def self.strip(text)
    text.to_s.lines.reject { |line| line.start_with?(PREFIX) }.join.strip.presence
  end

  def self.description_for(meeting)
    return meeting.description if meeting.attendee_emails.present?

    [strip(meeting.description), "#{PREFIX}#{url_for(meeting)}"].compact.join("\n\n")
  end

  def self.url_for(meeting)
    base = "#{ENV.fetch('FRONTEND_URL', '')}/app/accounts/#{meeting.account_id}"
    return "#{base}/tickets/#{meeting.case_ticket_id}" if meeting.case_ticket_id

    "#{base}/contacts/#{meeting.contact_id}"
  end
end
