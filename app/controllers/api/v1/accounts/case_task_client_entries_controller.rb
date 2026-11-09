# frozen_string_literal: true

# Tareas con el cliente — lo que pasó en su portal sobre una tarea, desde la plataforma.
#   GET  …/case_tickets/:case_ticket_id/tasks/:case_task_id/client_entries         → entradas (con archivos)
#   POST …/case_tickets/:case_ticket_id/tasks/:case_task_id/client_entries         { content } responderle
#   POST …/case_tickets/:case_ticket_id/tasks/:case_task_id/client_entries/return  { reason } regresarla a pendiente
# Mismos permisos que las tareas del caso (área Casos; para escribir, poder escribir).
class Api::V1::Accounts::CaseTaskClientEntriesController < Api::V1::Accounts::BaseController
  before_action :set_task

  def index
    render json: { entries: @task.client_entries.ordered.includes(:user, :contact).with_attached_file.map { |e| entry_json(e) } }
  end

  def create
    entry = ClientTasks::Recorder.new(@task, user: current_user).comment(params[:content])
    render json: { entry: entry_json(entry) }, status: :created
  rescue ClientTasks::Recorder::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def return_task
    entry = ClientTasks::Recorder.new(@task, user: current_user).return!(params[:reason])
    render json: { entry: entry_json(entry) }, status: :created
  rescue ClientTasks::Recorder::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_task
    ticket = account_case_tickets.find(params[:case_ticket_id])
    @task = ticket.case_tasks.find(params[:case_task_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tarea no encontrada' }, status: :not_found
  end

  def entry_json(entry)
    { id: entry.id, kind: entry.kind, content: entry.content, author: entry.author_name, by_client: entry.by_client?,
      created_at: entry.created_at,
      file: entry.file.attached? ? { name: entry.file.filename.to_s, url: rails_blob_path(entry.file, only_path: true) } : nil }
  end
end
