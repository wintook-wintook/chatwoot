# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Plantilla-Tareas-Etapa T1: tareas plantilla de una etapa
# ================================================================================
# GET    /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:column_id/tasks
# POST   /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:column_id/tasks
# PATCH  /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:column_id/tasks/:id
# DELETE /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:column_id/tasks/:id
# PUT    /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:column_id/tasks/reorder
#          { ids: [...] } → el orden de la lista
#
# Cambiar la plantilla no toca los casos que ya existen: aplica a las siguientes
# entradas a la etapa. Solo un administrador la cambia.
# ================================================================================

class Api::V1::Accounts::CaseTypeColumnTasksController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index]
  before_action :set_column
  before_action :set_task, only: %i[update destroy]

  def index
    render json: { tasks: @column.task_templates.map { |t| task_json(t) } }
  end

  def create
    task = @column.task_templates.build(task_params.merge(account: Current.account))
    task.position = (@column.task_templates.maximum(:position) || -1) + 1
    save_and_render(task, :created)
  rescue ArgumentError => e # valor fuera del enum (prioridad o responsable)
    render_error(e.message)
  end

  def update
    @task.assign_attributes(task_params)
    save_and_render(@task, :ok)
  rescue ArgumentError => e
    render_error(e.message)
  end

  def destroy
    @task.destroy
    head :no_content
  end

  def reorder
    ids = Array(params[:ids]).map(&:to_i)
    CaseTypeColumnTask.transaction do
      ids.each_with_index do |id, position|
        @column.task_templates.where(id: id).update_all(position: position) # rubocop:disable Rails/SkipsModelValidations
      end
    end
    render json: { tasks: @column.task_templates.reload.map { |t| task_json(t) } }
  end

  private

  def set_column
    case_type = Current.account.case_types.find(params[:case_type_id])
    @column = case_type.case_type_columns.find(params[:case_type_column_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Etapa no encontrada' }, status: :not_found
  end

  def set_task
    @task = @column.task_templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tarea no encontrada' }, status: :not_found
  end

  def task_params
    params.require(:task).permit(:title, :description, :required, :due_after_hours, :priority,
                                 :estimated_minutes, :assignee_mode, :assignee_id, :team_id)
  end

  def save_and_render(task, status)
    if task.save
      render json: { task: task_json(task) }, status: status
    else
      render_error(task.errors.full_messages.to_sentence)
    end
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def task_json(task)
    task.slice(:id, :title, :description, :required, :due_after_hours, :priority, :estimated_minutes,
               :assignee_mode, :assignee_id, :team_id, :position)
  end
end
