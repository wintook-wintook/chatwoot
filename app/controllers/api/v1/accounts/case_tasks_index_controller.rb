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
#
# @tickets_cases — `item_type` decide qué se lista: '' (default) fusiona tareas
# (CaseTask) y reuniones (CaseMeeting, "tareas agendadas" en el resto del código)
# en un solo feed ordenado por fecha; 'task' u 'meeting' devuelve solo uno de los
# dos. La consulta/orden/fusión vive en Cases::TasksInboxQuery — este controller
# solo autoriza y serializa.
# ================================================================================
class Api::V1::Accounts::CaseTasksIndexController < Api::V1::Accounts::BaseController
  include CaseMeetingSerializer

  def index
    result = Cases::TasksInboxQuery.new(account: Current.account, current_user: current_user, params: params).call
    @notes_count_map = notes_count_map_for(result[:rows])

    render json: {
      case_tasks: result[:rows].map { |record, kind| kind == :task ? task_json(record) : meeting_row_json(record) },
      meta: { current_page: result[:page], page_size: Cases::TasksInboxQuery::PER_PAGE, count: result[:total] }
    }
  end

  private

  # --- serialización: tareas ----------------------------------------------------
  # La tarea MÁS el contexto de su ticket: sin esto la bandeja no ahorra el
  # "entrar ticket por ticket" que motiva el plan.
  def task_json(task)
    {
      id: task.id,
      item_type: 'task',
      # Folio consecutivo de la tarea dentro de su ticket (T001, T002…), igual
      # que en la vista de tareas dentro del ticket.
      sequence: task.sequence,
      title: task.title,
      description: task.description,
      status: task.status,
      # @tickets_cases — prioridad de la TAREA. Ojo al leer el JSON: la del
      # ticket viaja aparte, dentro de `case_ticket`.
      priority: task.priority,
      assignee_id: task.assignee_id,
      assignee: ref_user(task.assignee),
      # @tickets_cases — solicitante (quién abrió la tarea), solo lectura.
      requester: ref_user(task.requester),
      due_at: task.due_at,
      position: task.position,
      completed_at: task.completed_at,
      completed_by: ref_user(task.completed_by),
      # @tickets_cases — nº de notas internas atadas a la tarea (columna "Notas").
      notes_count: (@notes_count_map || {})[task.id] || 0,
      case_ticket: ticket_context(task.case_ticket)
    }
  end

  # --- serialización: reuniones ("tareas agendadas") -----------------------------
  # `meeting_json` (CaseMeetingSerializer) ya trae sequence/folio/title/starts_at/
  # ends_at/status/organizer/case_task/etc. — solo se etiqueta el tipo y se suma
  # el contexto del ticket, igual que las tareas.
  def meeting_row_json(meeting)
    meeting_json(meeting).merge(
      item_type: 'meeting',
      case_ticket: ticket_context(meeting.case_ticket)
    )
  end

  # id de tarea → nº de notas internas, solo para las filas de tarea de la
  # página actual (las reuniones no tienen este concepto).
  def notes_count_map_for(rows)
    ids = rows.filter_map { |record, kind| record.id if kind == :task }
    return {} if ids.empty?

    CaseEvent.where(account_id: Current.account.id, event_type: :internal_note)
             .where(case_task_id: ids)
             .group(:case_task_id).count
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
