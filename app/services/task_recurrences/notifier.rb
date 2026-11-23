# frozen_string_literal: true

# Tareas que se repiten — «no se hizo»: llegó la siguiente fecha y la anterior sigue pendiente. Le avisa al
# responsable y a quien la programó (si es otra persona). Campanita + toast + Mi día.
module TaskRecurrences::Notifier
  module_function

  def title(meta) = I18n.t('notifications.notification_title.task_recurrence_missed', title: meta&.dig('title').to_s)

  def body(meta)
    I18n.t('notifications.task_recurrence_missed.body', assignee: meta&.dig('assignee').to_s, due: meta&.dig('due').to_s)
  end

  def missed(recurrence, pending)
    due = pending.try(:due_at) || pending.try(:starts_at)
    meta = { 'title' => recurrence.title, 'assignee' => recurrence.assignee&.name.to_s,
             'due' => due && I18n.l(due.in_time_zone(recurrence.zone).to_date, format: :short) }
    [recurrence.assignee, recurrence.user].compact.uniq.each do |user|
      NotificationBuilder.new(notification_type: 'task_recurrence_missed', user: user, account: recurrence.account,
                              primary_actor: recurrence, secondary_actor: nil, meta: meta).perform
    rescue StandardError => e
      Rails.logger.warn("[TaskRecurrences::Notifier] #{recurrence.id} → #{user.id}: #{e.class}: #{e.message}")
    end
  end
end
