# frozen_string_literal: true

# Tareas con el cliente — lo que pasa en una tarea que trabaja el cliente en su portal:
#   started (la empezó) · comment · file (subió un archivo) · done (la completó)
#   returned (nosotros la regresamos a pendiente, con el porqué) · reply (le respondimos)
# Las del cliente llevan contact; las nuestras, user. Cada una queda en la actividad del
# caso (task_client_update). La crea ClientTasks::Recorder.
class CaseTaskClientEntry < ApplicationRecord
  KINDS = %w[started comment file done returned reply].freeze
  MAX_FILE_SIZE = 20.megabytes

  belongs_to :account
  belongs_to :case_task
  belongs_to :case_ticket
  belongs_to :contact, optional: true
  belongs_to :user, optional: true

  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :content, length: { maximum: 5000 }
  validate :file_rules

  after_create_commit :log_on_case

  scope :ordered, -> { order(:created_at, :id) }

  def author_name
    user&.name || contact&.name
  end

  def by_client?
    user_id.nil?
  end

  private

  def file_rules
    return errors.add(:file, 'es obligatorio') if kind == 'file' && !file.attached?
    return unless file.attached?

    errors.add(:file, 'es muy grande (máximo 20 MB)') if file.blob.byte_size > MAX_FILE_SIZE
  end

  def log_on_case
    CaseEvent.create!(account_id: account_id, case_ticket_id: case_ticket_id, case_task_id: case_task_id,
                      event_type: :task_client_update, origin: user_id ? :agent : :system, actor: user, payload: event_payload)
  rescue StandardError => e
    Rails.logger.error("[ClientTasks] bitácora de la tarea #{case_task_id}: #{e.message}")
  end

  def event_payload
    { sequence: case_task.sequence, title: case_task.title, kind: kind, contact: contact&.name,
      content: content.to_s.truncate(300).presence, file: (file.filename.to_s if file.attached?) }.compact
  end
end
