# frozen_string_literal: true

# Plan Actividad del caso — todo lo que pasó en el caso en una sola lista, de lo
# más nuevo a lo más viejo:
#   • la bitácora (case_events): cambios, notas, tareas, tareas agendadas, cotizaciones…
#   • los mensajes de TODAS sus conversaciones (principal y adicionales, p. ej. el
#     correo), resumidos por día y conversación: «5 mensajes por WhatsApp».
# Además un resumen para la tarjeta «¿cómo va?»: qué sigue y el último contacto.
# Los mensajes no se copian a ningún lado: se leen de las conversaciones.
class Cases::ActivityFeed
  PREVIEW_LENGTH = 140
  CLIENT_TYPES = [Message.message_types[:incoming], Message.message_types[:outgoing]].freeze

  def initialize(ticket:, zone: nil)
    @ticket = ticket
    @zone = zone || Time.zone
  end

  def call
    { items: (event_items + message_items).sort_by { |item| -item[:at].to_f }, summary: summary,
      conversations: conversations.map { |c| conversation_ref(c) } }
  end

  private

  attr_reader :ticket, :zone

  def conversations
    @conversations ||= ticket.linked_conversations
  end

  # --- bitácora ------------------------------------------------------------------
  def event_items
    ticket.case_events.includes(:actor).map do |event|
      { kind: 'event', id: event.id, at: event.created_at, event_type: event.event_type, origin: event.origin,
        payload: event.payload, case_task_id: event.case_task_id, actor: user_ref(event.actor) }
    end
  end

  # --- mensajes, por día y conversación ---------------------------------------------
  def message_items
    return [] if conversations.empty?

    previews = last_message_by_group
    message_groups.map do |row|
      key = [row['conversation_id'], row['day'].to_s]
      { kind: 'messages', id: "#{key[0]}-#{key[1]}", at: row['last_at'].in_time_zone, day: key[1],
        first_at: row['first_at'].in_time_zone, incoming: row['incoming'], outgoing: row['outgoing'],
        conversation: conversation_ref(conversations_by_id[row['conversation_id']]), last: previews[key] }
    end
  end

  def client_messages
    Message.unscope(:order).where(conversation_id: conversations.map(&:id), message_type: CLIENT_TYPES, private: false)
  end

  def local_day
    "(messages.created_at AT TIME ZONE 'UTC' AT TIME ZONE #{Message.connection.quote(zone.tzinfo.name)})::date"
  end

  def message_groups
    sql = client_messages.select(
      'messages.conversation_id', "#{local_day} AS day",
      "COUNT(*) FILTER (WHERE message_type = #{CLIENT_TYPES[0]}) AS incoming",
      "COUNT(*) FILTER (WHERE message_type = #{CLIENT_TYPES[1]}) AS outgoing",
      'MIN(messages.created_at) AS first_at', 'MAX(messages.created_at) AS last_at'
    ).group('messages.conversation_id', 'day').to_sql
    Message.connection.select_all(sql).to_a.map { |row| cast_group(row) }
  end

  def cast_group(row)
    type = ActiveRecord::Type::DateTime.new
    row.merge('first_at' => type.cast(row['first_at']), 'last_at' => type.cast(row['last_at']),
              'conversation_id' => row['conversation_id'].to_i)
  end

  # El último mensaje de cada día y conversación: de quién y qué dijo.
  def last_message_by_group
    client_messages.select("DISTINCT ON (messages.conversation_id, #{local_day}) messages.*, #{local_day} AS day")
                   .order(Arel.sql("messages.conversation_id, #{local_day}, messages.created_at DESC"))
                   .includes(:sender)
                   .index_by { |m| [m.conversation_id, m.day.to_s] }
                   .transform_values { |m| message_preview(m) }
  end

  def message_preview(message)
    { incoming: message.incoming?, sender: message.sender.try(:name),
      content: message.content.to_s.squish.truncate(PREVIEW_LENGTH) }
  end

  # --- «¿cómo va?» -------------------------------------------------------------------
  def summary
    { next_task: next_task, next_meeting: next_meeting, overdue_tasks: pending_tasks.where(due_at: ...Time.current).count,
      pending_tasks: pending_tasks.count, last_incoming: last_message(:incoming), last_outgoing: last_message(:outgoing) }
  end

  def pending_tasks
    ticket.case_tasks.pending
  end

  def next_task
    task = pending_tasks.includes(:assignee).order(Arel.sql('due_at ASC NULLS LAST'), :position, :id).first
    task && { id: task.id, sequence: task.sequence, title: task.title, due_at: task.due_at,
              assignee: user_ref(task.assignee) }
  end

  def next_meeting
    meeting = ticket.case_meetings.scheduled.where(starts_at: Time.current..).includes(:organizer).order(:starts_at).first
    meeting && { id: meeting.id, title: meeting.title, starts_at: meeting.starts_at, organizer: user_ref(meeting.organizer) }
  end

  def last_message(type)
    message = client_messages.where(message_type: type).order(created_at: :desc).first
    message && { at: message.created_at, conversation: conversation_ref(conversations_by_id[message.conversation_id]) }
  end

  # --- referencias -------------------------------------------------------------------
  def conversations_by_id
    @conversations_by_id ||= conversations.index_by(&:id)
  end

  def conversation_ref(conversation)
    return nil unless conversation

    { display_id: conversation.display_id, primary: conversation.id == ticket.conversation_id,
      inbox_name: conversation.inbox&.name, channel_type: conversation.inbox&.channel_type,
      subject: conversation.additional_attributes&.dig('mail_subject') }
  end

  def user_ref(user)
    user && { id: user.id, name: user.name, avatar_url: user.avatar_url }
  end
end
