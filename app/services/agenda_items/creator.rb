# Plan-Agenda A2 — da de alta la tarea agendada del calendario, con su contacto o dentro
# de un caso. Con `google_event_id` nace de ese evento de Google, sin tocar sus fechas ni
# avisar a sus invitados. Lo de todo el día no lleva hora: se queda solo en Google.
class AgendaItems::Creator
  class AlreadyLinked < StandardError; end
  class AllDayEvent < StandardError; end

  def initialize(account:, user:, attrs:, client: {}, organizer: nil)
    @account = account
    @user = user
    @attrs = attrs
    @client = client
    @organizer = organizer || user
  end

  def call
    @attrs[:google_event_id].present? ? from_google_event : from_form
  end

  private

  def from_form
    meeting = build(@attrs)
    meeting.save!
    AgendaItems::Linker.meeting_added(meeting, @user)
    Cases::MeetingSyncJob.perform_later(meeting.id, 'create')
    meeting
  end

  def from_google_event
    raise AlreadyLinked if @account.case_meetings.exists?(google_event_id: @attrs[:google_event_id])

    event = read_event
    raise AllDayEvent if event.dig('start', 'dateTime').blank?

    meeting = build(google_attrs(event))
    meeting.google_event_id = event['id']
    meeting.save!
    AgendaItems::Linker.meeting_added(meeting, @user)
    AgendaItems::EventLineJob.perform_later(meeting.id)
    meeting
  end

  def calendar_id
    @attrs[:calendar_id].presence || 'primary'
  end

  def read_event
    integration = UserCalendarIntegration.find_by!(account_id: @account.id, user_id: @user.id)
    event = GoogleCalendarService.new(integration).get_event(@attrs[:google_event_id], calendar_id: calendar_id)
    raise ActiveRecord::RecordNotFound if event == :already_gone || event['status'] == 'cancelled'

    event
  end

  def google_attrs(event)
    { title: event['summary'].presence || I18n.t('agenda_items.untitled'), description: AgendaItems::EventLine.strip(event['description']),
      location: event['location'], starts_at: event.dig('start', 'dateTime'), ends_at: event.dig('end', 'dateTime'),
      meeting_url: GoogleCalendarService.meet_url_from(event), calendar_id: calendar_id,
      attendee_emails: Array(event['attendees']).reject { |a| a['self'] || a['organizer'] }.pluck('email'),
      sync_status: :synced }
  end

  def build(attrs)
    CaseMeeting.new(account: @account, organizer: @organizer, **@client,
                    title: attrs[:title], description: attrs[:description], starts_at: attrs[:starts_at], ends_at: attrs[:ends_at],
                    location: attrs[:location], meeting_url: attrs[:meeting_url], attendee_emails: Array(attrs[:attendee_emails]),
                    is_visit: attrs[:is_visit] || false, google_calendar_id: attrs[:calendar_id].presence,
                    sync_status: attrs[:sync_status] || :pending)
  end
end
