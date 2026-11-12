# frozen_string_literal: true

# Asistente (Dali) — cómo se le cuentan al modelo los registros (casos, contactos,
# tareas, agenda, actividad): pocos datos, fechas en la hora local del usuario.
module Assistant::ToolRefs
  private

  def open_cases_of(contact)
    cases.where(contact_id: contact.id).where.not(status: CaseTicket::CLOSED_STATUSES)
         .order(updated_at: :desc).limit(10).map { |t| case_ref(t) }
  end

  def pending_tasks_of(contact)
    @account.case_tasks.pending.where(contact_id: contact.id).limit(10).map { |t| task_ref(t) }
  end

  def upcoming_of(contact)
    @account.case_meetings.scheduled.where(contact_id: contact.id, starts_at: Time.current..)
            .order(:starts_at).limit(10).map { |m| meeting_ref(m) }
  end

  def conversations_of(contact)
    contact.conversations.where(account_id: @account.id).order(last_activity_at: :desc).limit(8).map do |c|
      { id: c.display_id, inbox: c.inbox&.name, status: c.status, last_activity: local(c.last_activity_at) }
    end
  end

  def contact_ref(contact)
    { id: contact.id, name: contact.name, email: contact.email, phone: contact.phone_number,
      organization: contact.try(:organization)&.name || contact.additional_attributes&.dig('company_name') }
  end

  def case_ref(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, status: ticket.status,
      type: ticket.case_type&.name, class: ticket.case_type&.case_class,
      contact: ticket.contact && { id: ticket.contact_id, name: ticket.contact.name } }
  end

  def commercial(ticket)
    return nil unless ticket.case_type&.case_class == 'commercial'

    { amount: ticket.try(:amount)&.to_s, currency: ticket.try(:currency), probability: ticket.try(:probability),
      expected_close_at: ticket.try(:expected_close_at)&.to_s, outcome: ticket.try(:outcome) }
  end

  # El día en que vence una tarea (sin hora: vence al final de ese día).
  def due_on(time) = time&.in_time_zone(@zone)&.strftime('%Y-%m-%d')

  def task_ref(task)
    { id: task.id, title: task.title, due_on: due_on(task.due_at), # una tarea vence en un día, sin hora
      case: task.case_ticket&.folio, contact: task.contact&.name }
  end

  def meeting_ref(meeting)
    { id: meeting.id, title: meeting.title, starts_at: local(meeting.starts_at), status: meeting.status,
      case: meeting.case_ticket&.folio, contact: meeting.contact&.name || meeting.case_ticket&.contact&.name }
  end

  def conversation_ref(ref)
    { id: ref[:display_id], inbox: ref[:inbox_name], primary: ref[:primary], subject: ref[:subject] }.compact
  end

  def conversation_label(conversation)
    return "Chat interno · #{room_name(conversation)}" if conversation.internal?

    "##{conversation.display_id} · #{conversation.inbox&.name} · #{conversation.contact&.name}"
  end

  def summary_text(summary)
    { next_task: summary[:next_task] && { title: summary[:next_task][:title], due_on: due_on(summary[:next_task][:due_at]) },
      next_meeting: summary[:next_meeting] && { title: summary[:next_meeting][:title], starts_at: local(summary[:next_meeting][:starts_at]) },
      pending_tasks_total: summary[:pending_tasks], of_which_overdue: summary[:overdue_tasks],
      last_customer_message: local(summary.dig(:last_incoming, :at)), last_our_message: local(summary.dig(:last_outgoing, :at)) }
  end

  def activity_line(item)
    return messages_line(item) if item[:kind] == 'messages'

    payload = item[:payload] || {}
    detail = payload['content'] || payload['title'] || [payload['from'], payload['to']].compact.join(' → ')
    [local(item[:at]), item[:event_type], item.dig(:actor, :name), detail.to_s.truncate(160)].compact_blank.join(' · ')
  end

  def messages_line(item)
    last = item[:last] || {}
    who = last[:incoming] ? 'cliente' : 'nosotros'
    "#{item[:day]} · mensajes (#{item.dig(:conversation, :inbox_name)}): #{item[:incoming]} del cliente, " \
      "#{item[:outgoing]} nuestros · último (#{who}): #{last[:content]}"
  end
end
