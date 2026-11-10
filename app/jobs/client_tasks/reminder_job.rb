# frozen_string_literal: true

# Tareas con el cliente — una vez al día: las que vencen en las próximas 24 h y las que
# vencieron ayer. Le avisa al cliente (si su conversación lo permite) y al responsable del
# caso (campanita). Por las ventanas de 24 h cada tarea recibe cada aviso una sola vez.
class ClientTasks::ReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    now = Time.current
    remind(scope.where(due_at: now..(now + 24.hours)), :due_soon)
    remind(scope.where(due_at: (now - 48.hours)...(now - 24.hours)), :overdue)
  end

  private

  def scope
    CaseTask.for_client.pending.where.not(case_ticket_id: nil).includes(case_ticket: %i[account contact organization assignee])
  end

  def remind(tasks, kind)
    tasks.find_each do |task|
      next if CaseTicket::CLOSED_STATUSES.include?(task.case_ticket.status)

      ClientTasks::Notifier.new(task).call(kind)
      notify_team(task, kind)
    rescue StandardError => e
      Rails.logger.error("[ClientTasks] recordatorio de la tarea #{task.id}: #{e.message}")
    end
  end

  def notify_team(task, kind)
    recipient = task.case_ticket.assignee
    return unless recipient

    NotificationBuilder.new(notification_type: 'client_task_update', user: recipient, account: task.account,
                            primary_actor: task.case_ticket, meta: { task_title: task.title, kind: kind.to_s }).perform
  end
end
