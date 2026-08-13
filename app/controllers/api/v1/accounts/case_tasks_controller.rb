# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Tareas / subtareas de un ticket (osTicket "Tasks")
# ================================================================================
# GET    /api/v1/accounts/:id/case_tickets/:case_ticket_id/tasks
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/tasks
# PATCH  /api/v1/accounts/:id/case_tickets/:case_ticket_id/tasks/:id
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/tasks/:id
# ================================================================================

class Api::V1::Accounts::CaseTasksController < Api::V1::Accounts::BaseController
  FROZEN_MSG = 'Ticket cerrado: no se pueden modificar las tareas. Reábrelo si necesitas cambiarlas.'

  before_action :set_ticket
  before_action :set_task, only: %i[update destroy]

  def index
    render json: { case_tasks: @ticket.case_tasks.ordered.map { |t| task_json(t) } }
  end

  def create
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?

    task = @ticket.case_tasks.build(task_params)
    task.account = Current.account
    # @tickets_cases — solicitante = agente actual, fijado al crear (no editable).
    task.requester = current_user
    task.position ||= @ticket.case_tasks.count
    if task.save
      notify_task_assignment(task) # F3 — avisa al recién asignado (si no soy yo)
      render json: { case_task: task_json(task) }, status: :created
    else
      render json: { error: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Cerrado = solo lectura, sin excepciones: tampoco se marcan tareas como
    # completadas. Si hay que tocar algo, se reabre el ticket.
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?

    prev_assignee_id = @task.assignee_id
    was_done = @task.done?

    # @tickets_cases — solicitante: solo se puede fijar si aún NO tiene (tareas
    # antiguas). Una vez puesto es firma inmutable, no se reasigna.
    assign_requester_if_absent

    prev_due_at = @task.due_at

    if @task.update(task_params)
      # F3 — si cambió el asignado a alguien que no soy yo.
      notify_task_assignment(@task) if @task.assignee_id != prev_assignee_id
      # F4 — si la tarea pasó a completada (avisa a ticket.assignee + task.assignee).
      notify_task_completed(@task) if @task.done? && !was_done
      # @tickets_cases F5 (§11.2/§11.1) — reuniones de la tarea. Ninguna de las dos
      # acciones ocurre sola: el front manda la bandera solo si el agente la aceptó
      # en el diálogo, con las reuniones a la vista.
      render json: { case_task: task_json(@task) }.merge(meeting_lifecycle(prev_due_at))
    else
      render json: { error: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?

    @task.destroy
    head :no_content
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def set_task
    @task = @ticket.case_tasks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tarea no encontrada' }, status: :not_found
  end

  def task_params
    permitted = params.require(:case_task).permit(:title, :description, :status, :priority, :assignee_id, :due_at, :position)
    # El asignado debe ser un usuario de la cuenta (si no, queda sin asignar).
    permitted[:assignee_id] = Current.account.users.where(id: permitted[:assignee_id]).pick(:id) if permitted.key?(:assignee_id)
    permitted
  end

  # F5 — al completar la tarea, cancelar sus reuniones futuras; al mover el
  # vencimiento, extender la serie hasta la fecha nueva. Devuelve lo que pasó para
  # que la UI lo confirme en un toast.
  def meeting_lifecycle(prev_due_at)
    result = {}
    result[:cancelled_meetings] = cancel_task_meetings if cast_flag(:cancel_meetings)
    result[:extended_meetings] = extend_task_series(prev_due_at) if cast_flag(:extend_series)
    result
  end

  def cancel_task_meetings
    service = Cases::Meetings::LifecycleService.new(@ticket, actor: current_user)
    service.cancel!(service.pending(case_task: @task).to_a)
  end

  # La serie de la tarea se estira hasta el vencimiento nuevo (§11.1). Si el
  # vencimiento no se movió hacia adelante, no hay nada que extender.
  def extend_task_series(prev_due_at)
    return 0 if @task.due_at.blank? || (prev_due_at.present? && @task.due_at <= prev_due_at)

    series = @task.case_meeting_series.order(:id).last
    return 0 if series.nil?

    Cases::Meetings::LifecycleService.new(@ticket, actor: current_user)
                                     .extend_series_to(series, @task.due_at)
  end

  def cast_flag(name)
    ActiveModel::Type::Boolean.new.cast(params[name])
  end

  # Fija el solicitante desde la UI SOLO si la tarea aún no tiene (tareas creadas
  # antes de la función). Ya con solicitante, se ignora: es una firma inmutable.
  def assign_requester_if_absent
    return if @task.requester_id.present?

    rid = params.dig(:case_task, :requester_id).presence
    return if rid.nil?

    @task.requester_id = Current.account.users.where(id: rid).pick(:id)
  end

  def task_json(task)
    {
      id: task.id,
      sequence: task.sequence,
      title: task.title,
      description: task.description,
      status: task.status,
      # @tickets_cases — prioridad de la TAREA, independiente de la del ticket.
      priority: task.priority,
      assignee_id: task.assignee_id,
      assignee: ref_user(task.assignee),
      # @tickets_cases — solicitante (quién abrió la tarea), solo lectura.
      requester: ref_user(task.requester),
      due_at: task.due_at,
      position: task.position,
      created_at: task.created_at,
      # @tickets_cases P4 — firma de completado (quién y cuándo).
      completed_at: task.completed_at,
      completed_by: ref_user(task.completed_by),
      # @tickets_cases — cuántas notas internas cuelgan de esta tarea (columna
      # "Notas" en la tabla). Mapa agrupado para no consultar por fila.
      notes_count: notes_count_map[task.id] || 0,
      # @tickets_cases F6 (§11.4) — la tarea se marca si alguna de sus reuniones
      # quedó DESPUÉS de su vencimiento (mismo marcador hermano que la tarea
      # vencida). Mapa agrupado: una consulta por request, no una por fila.
      meetings_beyond_due: meetings_beyond_due_map[task.id] || 0
    }
  end

  # id de tarea → nº de reuniones vivas que caen después del vencimiento de esa
  # tarea. Se compara en SQL contra `case_tasks.due_at`.
  def meetings_beyond_due_map
    @meetings_beyond_due_map ||= CaseMeeting
                                 .joins(:case_task)
                                 .where(case_ticket_id: @ticket.id, status: %i[scheduled rescheduled])
                                 .where('case_tasks.due_at IS NOT NULL AND case_meetings.starts_at > case_tasks.due_at')
                                 .group(:case_task_id).count
  end

  # id de tarea → nº de notas internas (una sola consulta agrupada por request).
  def notes_count_map
    @notes_count_map ||= @ticket.case_events
                                .where(event_type: :internal_note)
                                .where.not(case_task_id: nil)
                                .group(:case_task_id).count
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name }
  end

  # ── Notificaciones de tarea (F3/F4) ─────────────────────────────────────
  # primary_actor = el TICKET (reusa el ruteo de case_ticket_assignment); el
  # nombre de la tarea viaja en meta. Fallan en silencio: nunca rompen el flujo.

  # F3 — asignación: avisa al responsable recién asignado. Por decisión del
  # producto (2026-07-29) SÍ notifica auto-asignaciones (a diferencia de tickets).
  def notify_task_assignment(task)
    assignee = task.assignee
    return if assignee.nil?

    build_task_notification('case_task_assignment', assignee, task)
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] notificación de asignación de tarea: #{e.message}")
  end

  # F4 — completado: avisa al asignado del ticket y al de la tarea, menos a quien
  # marcó, deduplicando cuando coinciden y saltando los nil.
  def notify_task_completed(task)
    recipients = [task.case_ticket&.assignee_id, task.assignee_id]
                 .compact.uniq - [current_user&.id]
    return if recipients.empty?

    users = Current.account.users.where(id: recipients)
    users.each { |u| build_task_notification('case_task_completed', u, task) }
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] notificación de tarea completada: #{e.message}")
  end

  def build_task_notification(type, user, task)
    NotificationBuilder.new(
      notification_type: type,
      user: user,
      account: Current.account,
      primary_actor: task.case_ticket,
      meta: { task_title: task.title }
    ).perform
  end
end
