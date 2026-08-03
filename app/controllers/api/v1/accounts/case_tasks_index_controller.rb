# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Bandeja de tareas (F1): índice de tareas a nivel CUENTA.
# ================================================================================
# GET /api/v1/accounts/:account_id/case_tasks
#
# Responde "¿qué tareas tengo asignadas?" sin entrar ticket por ticket. A
# diferencia de CaseTasksController (anidado bajo un ticket), aquí NO hay
# before_action :set_ticket: el scope es la cuenta y cada tarea viaja con el
# contexto de su ticket padre (folio, estado, prioridad, SLA, tipo).
#
# Visibilidad DECIDIDA (plan §3.1): por cuenta, sin guard de rol. Cualquier
# agente puede filtrar por cualquier otro (default = mis tareas, por comodidad).
# Ver: docs/vault-tickets/implementacion/Plan-Bandeja-Tareas.md
# ================================================================================
class Api::V1::Accounts::CaseTasksIndexController < Api::V1::Accounts::BaseController
  PER_PAGE = 25

  def index
    scope = filtered_scope
    total = scope.count
    page  = [params[:page].to_i, 1].max
    rows  = scope.ordered
                 .includes(:assignee, case_ticket: :case_type)
                 .limit(PER_PAGE)
                 .offset((page - 1) * PER_PAGE)

    render json: {
      case_tasks: rows.map { |t| task_json(t) },
      meta: { current_page: page, page_size: PER_PAGE, count: total }
    }
  end

  private

  def base_scope
    CaseTask.where(account_id: Current.account.id)
  end

  # Aplica los filtros de la bandeja (todos opcionales salvo el default de asignado).
  def filtered_scope
    scope = filter_assignee(base_scope)
    scope = filter_status(scope)
    scope = filter_due(scope)
    scope = filter_case_type(scope)
    filter_search(scope)
  end

  # assignee_id: ausente → mis tareas · 'all' → todos los agentes (sin filtro) ·
  # 'unassigned' → huérfanas · id → ese agente.
  def filter_assignee(scope)
    raw = params[:assignee_id].presence

    return scope if raw == 'all'
    return scope.where(assignee_id: nil) if raw == 'unassigned'
    return scope.where(assignee_id: current_user.id) if raw.nil?

    scope.where(assignee_id: raw)
  end

  # status: ausente → pending · 'done' → completadas · 'all'/'' → todas.
  def filter_status(scope)
    raw = params[:status]

    return scope if ['all', ''].include?(raw)
    return scope.where(status: CaseTask.statuses[raw]) if CaseTask.statuses.key?(raw)

    scope.pending
  end

  # due: overdue (vencidas y aún pendientes) · today · week (próximos 7 días).
  def filter_due(scope)
    case params[:due]
    when 'overdue'
      scope.pending.where('case_tasks.due_at < ?', Time.current)
    when 'today'
      scope.where(due_at: Time.zone.today.all_day)
    when 'week'
      scope.where(due_at: Time.zone.today.beginning_of_day..6.days.from_now.end_of_day)
    else
      scope
    end
  end

  def filter_case_type(scope)
    return scope if params[:case_type_id].blank?

    scope.joins(:case_ticket).where(case_tickets: { case_type_id: params[:case_type_id] })
  end

  def filter_search(scope)
    return scope if params[:q].blank?

    like = "%#{params[:q].to_s.strip}%"
    scope.where('case_tasks.title ILIKE :q OR case_tasks.description ILIKE :q', q: like)
  end

  # --- serialización --------------------------------------------------------
  # La tarea MÁS el contexto de su ticket: sin esto la bandeja no ahorra el
  # "entrar ticket por ticket" que motiva el plan.
  def task_json(task)
    {
      id: task.id,
      # Folio consecutivo de la tarea dentro de su ticket (T001, T002…), igual
      # que en la vista de tareas dentro del ticket.
      sequence: task.sequence,
      title: task.title,
      description: task.description,
      status: task.status,
      assignee_id: task.assignee_id,
      assignee: ref_user(task.assignee),
      due_at: task.due_at,
      position: task.position,
      completed_at: task.completed_at,
      completed_by: ref_user(task.completed_by),
      case_ticket: ticket_context(task.case_ticket)
    }
  end

  def ticket_context(ticket)
    return nil unless ticket

    {
      id: ticket.id,
      folio: ticket.folio,
      title: ticket.title,
      status: ticket.status,
      priority: ticket.priority,
      sla_status: ticket.sla_status,
      case_type: ticket_type(ticket.case_type)
    }
  end

  def ticket_type(type)
    return nil unless type

    { id: type.id, name: type.name, color: type.color }
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name, thumbnail: user.avatar_url }
  end
end
