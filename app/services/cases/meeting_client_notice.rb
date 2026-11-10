# frozen_string_literal: true

# Avisarle al cliente por su conversación que una tarea agendada ya no va (se canceló o se
# quitó de la agenda). Solo si hay conversación y la ventana de 24 h lo permite.
#   Cases::MeetingClientNotice.call(meeting, user, i18n_key) → { sent: true } | { sent: false, reason: }
module Cases::MeetingClientNotice
  module_function

  def call(meeting, user, i18n_key)
    conversation = customer_conversation(meeting)
    return { sent: false, reason: 'no_conversation' } unless conversation
    return { sent: false, reason: 'window_closed' } unless conversation.can_reply?

    Messages::MessageBuilder.new(user, conversation, { content: message(meeting, i18n_key), message_type: 'outgoing' }).perform
    { sent: true }
  end

  def customer_conversation(meeting)
    contact = meeting.client_contact
    return if contact.nil?

    meeting.case_ticket&.conversation ||
      meeting.account.conversations.where(contact_id: contact.id).order(last_activity_at: :desc).first
  end

  def message(meeting, i18n_key)
    I18n.with_locale(meeting.account.locale.presence || I18n.default_locale) do
      I18n.t(i18n_key, name: meeting.client_contact&.name.to_s.split.first.to_s, title: meeting.title,
                       when: meeting.starts_at.in_time_zone.strftime('%d/%m %H:%M'))
    end
  end
end
