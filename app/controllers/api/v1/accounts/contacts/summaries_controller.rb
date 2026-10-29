# Página del contacto › Resumen: cuatro cifras y la actividad reciente mezclada
# (conversaciones, casos, notas y Agentes IA). Respeta el rol: con «solo lo
# suyo» solo cuenta las conversaciones y casos que el usuario puede ver, y sin
# «ver montos» no manda importes.
#
#   GET /contacts/:contact_id/summary
class Api::V1::Accounts::Contacts::SummariesController < Api::V1::Accounts::Contacts::BaseController
  ACTIVITY_LIMIT = 15
  CASE_EVENTS = %i[ticket_created status_changed column_changed assigned reassigned resolved reopened closed].freeze

  def show
    render json: { stats: stats, activity: activity }
  end

  private

  def conversations
    access_grant.conversations(Current.account.conversations).where(contact_id: @contact.id)
  end

  def tickets
    @tickets ||= access_grant.case_tickets(Current.account.case_tickets).where(contact_id: @contact.id)
  end

  def open_tickets
    tickets.where(status: CaseTicket::PENDING_STATUSES)
  end

  def stats
    opportunities = open_tickets.commercial.where(outcome: nil)
    {
      open_conversations: conversations.where(status: %i[open pending]).count,
      open_cases: open_tickets.count,
      opportunities_count: opportunities.count,
      opportunities_amounts: access_grant.can?(:see_amounts) ? amounts(opportunities) : nil,
      next_task: next_task,
      last_activity_at: @contact.last_activity_at
    }
  end

  def amounts(opportunities)
    opportunities.where.not(amount: nil).group(:currency).sum(:amount)
                 .map { |currency, amount| { currency: currency, amount: amount.to_f } }
  end

  # La tarea pendiente o la reunión más próxima de sus casos abiertos.
  def next_task
    ids = open_tickets.select(:id)
    task = CaseTask.pending.where(case_ticket_id: ids).where.not(due_at: nil).order(:due_at).first
    meeting = CaseMeeting.active.where(case_ticket_id: ids).where(starts_at: Time.current..).order(:starts_at).first
    item = [task && [task.due_at, task.title, 'task'], meeting && [meeting.starts_at, meeting.title, 'meeting']]
           .compact.min_by(&:first)
    item && { at: item[0], title: item[1], kind: item[2] }
  end

  def activity
    (conversation_items + case_items + note_items + ai_items)
      .sort_by { |item| item[:at] }.reverse.first(ACTIVITY_LIMIT)
  end

  def conversation_items
    conversations.includes(:inbox, :assignee).order(created_at: :desc).limit(ACTIVITY_LIMIT).map do |conversation|
      { kind: 'conversation', at: conversation.created_at, id: conversation.display_id,
        inbox: conversation.inbox&.name, user: conversation.assignee&.name }
    end
  end

  def case_items
    CaseEvent.where(case_ticket_id: tickets.select(:id), event_type: CASE_EVENTS)
             .includes(:case_ticket, :actor).order(created_at: :desc).limit(ACTIVITY_LIMIT).map do |event|
      ticket = event.case_ticket
      { kind: 'case', at: event.created_at, event: event.event_type, ticket_id: ticket.id,
        folio: ticket.folio, title: ticket.title, user: event.actor&.name }
    end
  end

  def note_items
    @contact.notes.includes(:user).order(created_at: :desc).limit(ACTIVITY_LIMIT).map do |note|
      text = ActionController::Base.helpers.strip_tags(note.content.to_s).squish.truncate(160)
      { kind: 'note', at: note.created_at, text: text, user: note.user&.name }
    end
  end

  def ai_items
    ContactTracking.where(contact_id: @contact.id).includes(:tracking_template)
                   .order(created_at: :desc).limit(ACTIVITY_LIMIT).map do |tracking|
      { kind: 'ai', at: tracking.created_at, name: tracking.tracking_template&.name, status: tracking.status }
    end
  end
end
