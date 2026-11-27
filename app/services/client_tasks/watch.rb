# frozen_string_literal: true

# Tareas con el cliente — «Esperando al cliente» en Mi día: las tareas del cliente de los casos donde la persona es
# responsable (la tarea del cliente no lleva responsable interno: la sigue el responsable del caso).
#   overdue  pendientes y vencidas (la más vieja primero)
#   soon     pendientes que vencen en los próximos 7 días
#   waiting  pendientes sin fecha o para más adelante
#   done     las que el cliente terminó en los últimos 7 días (para revisarlas o regresarlas)
#   ClientTasks::Watch.new(account, user).call → { counts: {…}, overdue: [rows], soon: […], waiting: […], done: […] }
class ClientTasks::Watch
  LIMIT = 15
  SOON = 7.days
  RECENT = 7.days

  def initialize(account, user, now: Time.current)
    @account = account
    @user = user
    @now = now
  end

  def call
    groups = { overdue: overdue, soon: soon, waiting: waiting, done: done }
    { counts: groups.transform_values(&:count) }.merge(groups.transform_values { |scope| scope.limit(LIMIT).map { |t| row(t) } })
  end

  private

  def scope
    CaseTask.where(account_id: @account.id).for_client.joins(:case_ticket).where(case_tickets: { assignee_id: @user.id })
            .includes(:completed_by_contact, case_ticket: %i[contact organization])
  end

  def pending = scope.pending

  def overdue = pending.where('case_tasks.due_at < ?', @now).order('case_tasks.due_at ASC')

  def soon = pending.where(case_tasks: { due_at: @now..(@now + SOON) }).order('case_tasks.due_at ASC')

  def waiting = pending.where('case_tasks.due_at IS NULL OR case_tasks.due_at > ?', @now + SOON).order('case_tasks.created_at DESC')

  def done = scope.done.where('case_tasks.completed_at >= ?', @now - RECENT).order('case_tasks.completed_at DESC')

  def row(task)
    ticket = task.case_ticket
    { id: task.id, title: task.title, due_at: task.due_at, status: task.status, client_status: task.client_status,
      completed_at: task.completed_at, completed_by: task.completed_by_contact&.name,
      days_overdue: days_overdue(task),
      case_ticket: { id: ticket.id, folio: ticket.folio, title: ticket.title },
      client: ticket.organization&.name || ticket.contact&.name }
  end

  def days_overdue(task)
    return nil unless task.pending? && task.due_at && task.due_at < @now

    ((@now - task.due_at) / 1.day).floor
  end
end
