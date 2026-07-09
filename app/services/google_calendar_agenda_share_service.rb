class GoogleCalendarAgendaShareService
  def initialize(account:, agent:, inbox_id:, contact_ids:, events:)
    @account    = account
    @agent      = agent
    @inbox      = account.inboxes.find(inbox_id)
    @contact_ids = contact_ids
    @events     = events
  end

  def perform
    @contact_ids.map do |contact_id|
      contact = @account.contacts.find(contact_id)
      send_to_contact(contact)
    end
  end

  private

  REQUIRES_EXISTING_CONVERSATION = %w[
    Channel::Telegram
    Channel::Line
    Channel::Instagram
    Channel::Facebook
  ].freeze

  def send_to_contact(contact)
    conversation = find_conversation(contact)
    return unless conversation

    Messages::MessageBuilder.new(
      @agent,
      conversation,
      { content: formatted_message, message_type: 'outgoing' }
    ).perform
  end

  def find_conversation(contact)
    contact_inbox = find_or_build_contact_inbox(contact)
    return nil unless contact_inbox

    if REQUIRES_EXISTING_CONVERSATION.include?(@inbox.channel_type)
      contact_inbox.conversations.order(last_activity_at: :desc).first
    else
      existing = contact_inbox.conversations.order(last_activity_at: :desc).first
      existing || create_conversation(contact_inbox)
    end
  end

  def create_conversation(contact_inbox)
    ConversationBuilder.new(
      params: ActionController::Parameters.new(assignee_id: @agent.id),
      contact_inbox: contact_inbox
    ).perform
  end

  def find_or_build_contact_inbox(contact)
    if REQUIRES_EXISTING_CONVERSATION.include?(@inbox.channel_type)
      contact.contact_inboxes.find_by(inbox: @inbox)
    else
      ContactInboxBuilder.new(contact: contact, inbox: @inbox).perform
    end
  end

  DAY_NAMES_ES   = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTH_NAMES_ES = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  def formatted_message
    grouped = @events.group_by do |e|
      date_str = e[:start_date] || e[:start_time]&.to_date&.iso8601
      date_str
    end.sort.to_h

    lines = ["📅 Mi agenda:\n"]

    grouped.each do |date, day_events|
      begin
        parsed = Date.parse(date.to_s)
        label  = "#{DAY_NAMES_ES[parsed.wday]} #{parsed.day} de #{MONTH_NAMES_ES[parsed.month - 1]}"
        lines << "\n#{label.capitalize}"
      rescue
        lines << "\n#{date}"
      end

      day_events.each do |event|
        time_label = if event[:all_day]
                       '(Todo el día)'
                     else
                       start_t = event[:start_time] ? event[:start_time].strftime('%H:%M') : ''
                       end_t   = event[:end_time]   ? event[:end_time].strftime('%H:%M')   : ''
                       "#{start_t} – #{end_t}"
                     end
        lines << "  • #{time_label}  #{event[:summary]}"
      end
    end

    lines.join("\n")
  end
end
