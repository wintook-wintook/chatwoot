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
    limit_to_own_tasks
    result = Cases::TasksInboxQuery.new(account: Current.account, current_user: current_user, params: params).call
    @notes_count_map = notes_count_map_for(result[:rows])

    @scores = result[:scores] || {}
    @planned_ids = result[:planned_ids]
    render json: {
      case_tasks: result[:rows].map { |record, kind| kind == :task ? task_json(record) : meeting_row_json(record) },
      meta: { current_page: result[:page], page_size: Cases::TasksInboxQuery::PER_PAGE, count: result[:total] }
        .merge(my_day_meta(result))
    }
  end

  # PUT /api/v1/accounts/:account_id/case_tasks/my_day_plan
  # Plan-Bandeja-Prioridad F2 — guarda el orden propio de «Mi día» del agente
  # actual: { day: 'YYYY-MM-DD' (local), task_ids: [...] en orden }. Reemplaza.
  def my_day_plan
    plan = Cases::MyDayPlan.new(account: Current.account, user: current_user, day: params[:day])
    render json: { day: plan.day, task_ids: plan.save!(params[:task_ids]) }
  end

  # POST /api/v1/accounts/:account_id/case_tasks/my_day_ai
  # Plan-Bandeja-Prioridad F4 — «Plan de mi día»: la IA explica «Mi día» del
  # agente actual (no lo reordena). { day: 'YYYY-MM-DD', tz: 'America/Mexico_City' }.
  def my_day_ai
    return render_ai_error('La IA de «Plan de mi día» está desactivada.') unless CaseAiConfig.for_account(Current.account).active?(:day_plan)

    planner = Cases::Ai::DayPlanner.new(account: Current.account)
    return render_ai_error('Configura la integración de OpenAI para usar la IA.') unless planner.available?

    tasks = my_day_for_ai
    return render_ai_error('No tienes tareas pendientes.') if tasks.empty?

    plan = planner.plan(user: current_user, tasks: tasks, agenda: @my_day[:agenda],
                        zone: ActiveSupport::TimeZone[params[:tz].to_s] || Time.zone)
    plan ? render(json: { plan: plan }) : render_ai_error('No se pudo generar el plan. Intenta de nuevo.')
  end

  private

  # Plan-Roles-Permisos — con Agenda en «solo lo suyo» se piden solo las propias
  # (o las sin asignar, si el rol puede tomarlas); cualquier otro valor → las mías.
  def limit_to_own_tasks
    return unless access_grant.own?(:agenda)
    return if params[:assignee_id].to_s == 'unassigned' && access_grant.can?(:take_unassigned)

    params[:assignee_id] = current_user.id.to_s
  end

  def render_ai_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  # «Mi día» del agente actual (primera página: el plan y las más urgentes).
  def my_day_for_ai
    query_params = params.permit(:day, :tz).merge(mode: 'my_day', assignee_id: current_user.id, page: 1)
    @my_day = Cases::TasksInboxQuery.new(account: Current.account, current_user: current_user, params: query_params).call
    @my_day[:rows].map do |task, _kind|
      @my_day[:scores][task.id].merge(task: task, planned: @my_day[:planned_ids].include?(task.id))
    end
  end

  # Plan-Bandeja-Prioridad F1 — «Mi día»: la agenda de hoy y la carga del día.
  def my_day_meta(result)
    return {} unless result.key?(:agenda)

    { agenda: result[:agenda].map { |meeting| meeting_row_json(meeting) }, load: result[:load],
      plan_count: result[:planned_ids].size, later_count: result[:later_count], missed: result[:missed],
      new_urgent: result[:new_urgent] }
  end

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
    }.merge(priority_fields(task)).merge(agenda_client(task))
  end

  # Plan-Bandeja-Prioridad F1 — duración estimada, hito y, en «Mi día», el
  # puntaje con sus motivos (score + reasons).
  def priority_fields(task)
    fields = { estimated_minutes: task.estimated_minutes, planned_on: task.planned_on, milestone: task.milestone,
               report_required: task.report_required? }
             .merge(@scores[task.id] || {})
    @planned_ids ? fields.merge(planned: @planned_ids.include?(task.id)) : fields
  end

  # --- serialización: reuniones ("tareas agendadas") -----------------------------
  # `meeting_json` (CaseMeetingSerializer) ya trae sequence/folio/title/starts_at/
  # ends_at/status/organizer/case_task/etc. — solo se etiqueta el tipo y se suma
  # el contexto del ticket, igual que las tareas.
  def meeting_row_json(meeting)
    meeting_json(meeting).merge(
      item_type: 'meeting',
      case_ticket: ticket_context(meeting.case_ticket)
    ).merge(agenda_client(meeting))
  end

  # Plan-Agenda A1 — sin caso, la fila dice de quién es.
  def agenda_client(record)
    { contact: record.contact&.slice(:id, :name), organization: record.organization&.slice(:id, :name) }
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
