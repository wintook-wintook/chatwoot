# frozen_string_literal: true

# ================================================================================
# Plan-Agenda — tareas de captura rápida: sin caso, solo en Kontrolya. Con contacto u
# organización se ven en su ficha; sin nada, solo en Mi día del responsable. Las que
# llevan caso se crean por el caso (case_tasks) y las de hora, por agenda_items.
# POST   /quick_tasks
# PATCH  /quick_tasks/:id
# DELETE /quick_tasks/:id
# ================================================================================
class Api::V1::Accounts::QuickTasksController < Api::V1::Accounts::BaseController
  include TaskReportGuard

  before_action :set_task, only: %i[update destroy]

  def create
    task = CaseTask.new(task_attrs.merge(client).merge(account: Current.account, requester: current_user))
    task.assignee ||= current_user
    task.save!
    render json: { case_task: task_json(task) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    return if !@task.done? && params[:status].to_s == 'done' && missing_task_report?(@task)

    if @task.update(task_attrs)
      render json: { case_task: task_json(@task) }
    else
      render json: { error: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    head :no_content
  end

  private

  def set_task
    @task = Current.account.case_tasks.without_case.find(params[:id])
    render_access_denied if access_grant.own?(:agenda) && [@task.assignee_id, @task.requester_id].exclude?(current_user.id)
  end

  def client
    { contact: (access_grant.contacts(Current.account.contacts).find(params[:contact_id]) if params[:contact_id].present?),
      organization: (Current.account.organizations.find(params[:organization_id]) if params[:organization_id].present?) }
  end

  def task_attrs
    attrs = params.permit(:title, :description, :status, :priority, :due_at, :planned_on, :estimated_minutes, :assignee_id)
    attrs[:assignee_id] = Current.account.users.where(id: attrs[:assignee_id]).pick(:id) if attrs.key?(:assignee_id)
    attrs
  end

  def task_json(task)
    task.slice(:id, :sequence, :title, :status, :due_at, :planned_on, :assignee_id, :contact_id, :organization_id)
  end
end
