# frozen_string_literal: true

# Tareas con el cliente — lo que se hace sobre una tarea del cliente, desde su portal
# (contact) o desde la plataforma (user). Cambia la tarea, deja la entrada (que va a la
# actividad del caso) y avisa:
#   start   el cliente la empezó («En proceso»)
#   comment comentario (del cliente o nuestro: reply)
#   attach  subió un archivo (con comentario opcional)
#   finish  el cliente la completó (si pide archivo, tiene que haber subido uno)
#   return  nosotros la regresamos a pendiente con el porqué
class ClientTasks::Recorder
  class Error < StandardError; end

  def initialize(task, contact: nil, user: nil)
    @task = task
    @contact = contact
    @user = user
  end

  def start
    ensure_open!
    @task.update!(client_status: 'in_progress')
    entry('started')
  end

  def comment(text)
    raise Error, I18n.t('client_portal.errors.empty_comment') if text.to_s.strip.blank?

    entry(@user ? 'reply' : 'comment', text)
  end

  def attach(file, text = nil)
    ensure_open!
    raise Error, I18n.t('client_portal.errors.no_file') if file.blank?

    entry('file', text, file: file)
  end

  def finish(text = nil)
    ensure_open!
    raise Error, I18n.t('client_portal.errors.file_required') if @task.requires_file && !@task.client_entries.exists?(kind: 'file')

    @task.update!(status: :done, completed_by_contact: @contact)
    entry('done', text).tap { notify_team('done') }
  end

  def return!(reason)
    raise Error, I18n.t('client_portal.errors.reason_required') if reason.to_s.strip.blank?

    @task.update!(status: :pending, client_status: nil)
    entry('returned', reason)
  end

  private

  def ensure_open!
    raise Error, I18n.t('client_portal.errors.closed') unless @task.pending? && @task.for_client?
  end

  def entry(kind, text = nil, file: nil)
    record = @task.client_entries.new(account_id: @task.account_id, case_ticket_id: @task.case_ticket_id, kind: kind,
                                      contact: @contact, user: @user, content: text.to_s.strip.first(5000).presence)
    record.file.attach(file) if file
    record.save!
    notify_team(kind) if @user.nil? && %w[comment file].include?(kind)
    record
  end

  # Al responsable del caso: campanita (Notification client_task_update).
  def notify_team(kind)
    recipient = @task.case_ticket&.assignee
    return if recipient.nil? || @user.present?

    NotificationBuilder.new(notification_type: 'client_task_update', user: recipient, account: @task.account,
                            primary_actor: @task.case_ticket,
                            meta: { task_title: @task.title, kind: kind, contact: @contact&.name }).perform
  rescue StandardError => e
    Rails.logger.error("[ClientTasks] aviso de la tarea #{@task.id}: #{e.message}")
  end
end
