# frozen_string_literal: true

# Tareas con el cliente — «Esperando al cliente» en Mi día (ClientTasks::Watch) y «Recordarle» desde ahí.
#   GET  case_tasks/client_watch?user_id=   las del cliente de los casos donde esa persona es responsable (ausente: yo)
#   POST case_tasks/:id/remind_client        le manda el recordatorio por su conversación con el enlace de su portal
#                                            (ClientTasks::Notifier: vencida o por vencer) → { sent:, reason: }
class Api::V1::Accounts::ClientTaskWatchesController < Api::V1::Accounts::BaseController
  def index
    user = params[:user_id].present? ? Current.account.users.find(params[:user_id]) : current_user
    render json: ClientTasks::Watch.new(Current.account, user).call
  end

  def remind
    task = Current.account.case_tasks.for_client.pending.find(params[:id])
    kind = task.due_at && task.due_at < Time.current ? :overdue : :due_soon
    render json: ClientTasks::Notifier.new(task, current_user).call(kind)
  end
end
