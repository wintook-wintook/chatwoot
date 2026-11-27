# frozen_string_literal: true

# Historial de la tarea (Cases::TaskHistory): GET /case_tasks/:id/history.
# Se ve si se ve su caso; sin caso, si es suya (quien la hace o la pidió) o si Agenda no
# está en «solo lo suyo».
class Api::V1::Accounts::TaskHistoriesController < Api::V1::Accounts::BaseController
  def show
    task = Current.account.case_tasks.find(params[:id])
    return render_access_denied unless visible?(task)

    render json: Cases::TaskHistory.new(task, file_url: ->(file) { url_for(file) }).call
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tarea no encontrada' }, status: :not_found
  end

  private

  def visible?(task)
    return account_case_tickets.exists?(id: task.case_ticket_id) if task.case_ticket_id
    return true if [task.assignee_id, task.requester_id].include?(current_user.id)

    !access_grant.own?(:agenda)
  end
end
