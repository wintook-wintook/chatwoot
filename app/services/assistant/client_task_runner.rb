# frozen_string_literal: true

# Asistente (Dali) — crea la tarea del cliente confirmada y, si se pidió, le avisa con el
# enlace de su portal (ClientTasks::Notifier). Se incluye en Assistant::Executor.
module Assistant::ClientTaskRunner
  def run_client_task(payload)
    ticket = writable_case(payload['case_id'])
    raise Assistant::Executor::Refused, 'Falta qué tiene que hacer el cliente.' if payload['title'].blank?

    task = ticket.case_tasks.create!(account: @account, requester: @user, audience: :client, title: payload['title'].to_s.first(255),
                                     description: payload['description'].presence, due_at: time(payload['due_at']),
                                     requires_file: payload['requires_file'] == true, position: ticket.case_tasks.count)
    notice = ClientTasks::Notifier.new(task, @user).call(:assigned) if payload['notify'] != false
    done(client_task_label(task, notice), case_path(ticket))
  end

  private

  def client_task_label(task, notice)
    label = "Tarea del cliente «#{task.title}»"
    return label if notice.nil?

    label + (notice[:sent] ? ' · se le avisó al cliente' : ' · no se le pudo avisar: mándale el enlace del portal')
  end
end
