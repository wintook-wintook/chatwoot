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
  FROZEN_MSG = 'Ticket cerrado: no se pueden modificar las tareas.'

  before_action :set_ticket
  before_action :set_task, only: %i[update destroy]

  def index
    render json: { case_tasks: @ticket.case_tasks.ordered.map { |t| task_json(t) } }
  end

  def create
    return render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?

    task = @ticket.case_tasks.build(task_params)
    task.account = Current.account
    task.position ||= @ticket.case_tasks.count
    if task.save
      render json: { case_task: task_json(task) }, status: :created
    else
      render json: { error: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # En un ticket cerrado solo se permite marcar/desmarcar el estado de una
    # tarea que quedó abierta: cerrar el ticket no debe obligar a mentir sobre
    # lo que sí se hizo. Editar título, responsable o fecha ya no.
    if @ticket.frozen_for_edit? && (task_params.keys - ['status']).any?
      return render json: { error: FROZEN_MSG }, status: :unprocessable_entity
    end

    if @task.update(task_params)
      render json: { case_task: task_json(@task) }
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
    permitted = params.require(:case_task).permit(:title, :description, :status, :assignee_id, :due_at, :position)
    # El asignado debe ser un usuario de la cuenta (si no, queda sin asignar).
    if permitted.key?(:assignee_id)
      permitted[:assignee_id] = Current.account.users.where(id: permitted[:assignee_id]).pick(:id)
    end
    permitted
  end

  def task_json(task)
    {
      id:           task.id,
      title:        task.title,
      description:  task.description,
      status:       task.status,
      assignee_id:  task.assignee_id,
      assignee:     ref_user(task.assignee),
      due_at:       task.due_at,
      position:     task.position,
      created_at:   task.created_at,
      # @tickets_cases P4 — firma de completado (quién y cuándo).
      completed_at: task.completed_at,
      completed_by: ref_user(task.completed_by)
    }
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name }
  end
end
