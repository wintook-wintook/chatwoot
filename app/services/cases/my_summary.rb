# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Mi resumen» (página Inicio): ¿qué tengo que hacer hoy?
# ================================================================================
# Lo que la página no saca de otros lados (Mi día y los avisos tienen su API):
#   conversations — mis conversaciones abiertas y las que esperan respuesta
#                   (el cliente escribió y nadie contestó), las que más llevan primero
#   cases         — mis casos abiertos con SLA en riesgo o vencido, los que ya
#                   terminaron las obligatorias de su etapa y las promesas de pago
#                   (comprometidas) de esta semana
#   week          — mis números de la semana (lunes a hoy) contra el mismo tramo de
#                   la semana pasada: casos resueltos o cerrados, tareas hechas y
#                   oportunidades ganadas
# ================================================================================

class Cases::MySummary
  LIST_LIMIT = 5
  READY_SCAN_LIMIT = 100

  def initialize(user:, account:)
    @user = user
    @account = account
  end

  def call
    { conversations: conversations, cases: cases, week: week }
  end

  private

  # --- conversaciones -------------------------------------------------------------

  def conversations
    open = @account.conversations.open.where(assignee_id: @user.id)
    waiting = open.where.not(waiting_since: nil)
    { open_count: open.count, waiting_count: waiting.count,
      waiting: waiting.order(:waiting_since).limit(LIST_LIMIT).includes(:contact, :inbox).map { |c| conversation_row(c) } }
  end

  def conversation_row(conversation)
    { id: conversation.display_id, contact: conversation.contact&.name, inbox: conversation.inbox&.name,
      waiting_since: conversation.waiting_since.to_i }
  end

  # --- casos ----------------------------------------------------------------------

  def my_open_cases
    @account.case_tickets.where(assignee_id: @user.id).where.not(status: CaseTicket::CLOSED_STATUSES)
  end

  def cases
    sla = my_open_cases.where(sla_status: %i[at_risk overdue])
    { sla_count: sla.count, sla: sla.order(:due_at).limit(LIST_LIMIT).map { |t| case_row(t) },
      ready: ready_cases, promises: promises }
  end

  # Casos cuya etapa ya terminó las obligatorias (sugerir: falta pasarlos o documentar).
  def ready_cases
    ids = CaseTask.where(required: true, case_ticket_id: my_open_cases.select(:id))
                  .distinct.limit(READY_SCAN_LIMIT).pluck(:case_ticket_id)
    CaseTicket.where(id: ids).includes(:case_type).filter_map do |ticket|
      summary = Cases::StageAdvance.new(ticket).summary
      next unless summary && summary[:ready] && summary[:mode] != 'manual'

      case_row(ticket).merge(stage: summary[:stage][:label], next: summary[:next]&.dig(:label),
                             needs_doc: summary[:needs_doc])
    end.first(LIST_LIMIT)
  end

  def promises
    week = Date.current.all_week
    my_open_cases.where.not(committed_at: nil).where(expected_close_at: week).order(:expected_close_at)
                 .limit(LIST_LIMIT).map do |t|
      case_row(t).merge(amount: t.amount&.to_f, currency: t.currency, on: t.expected_close_at)
    end
  end

  def case_row(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, sla_status: ticket.sla_status }
  end

  # --- la semana ------------------------------------------------------------------

  def week
    now = Time.current
    this_week = now.beginning_of_week..now
    last_week = (this_week.begin - 1.week)..(now - 1.week)
    { this_week: numbers(this_week), last_week: numbers(last_week) }
  end

  def numbers(range)
    mine = @account.case_tickets.where(assignee_id: @user.id)
    {
      cases_done: mine.where(resolved_at: range).or(mine.where(closed_at: range)).where(outcome: [nil, :won]).count,
      tasks_done: CaseTask.where(account_id: @account.id, completed_by_id: @user.id, completed_at: range).count,
      won: mine.where(outcome: :won, outcome_at: range).count
    }
  end
end
