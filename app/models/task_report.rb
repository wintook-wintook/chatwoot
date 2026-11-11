# == Schema Information
#
# Table name: task_reports
#
#  id                 :bigint           not null, primary key
#  closed_at          :datetime
#  content            :text             not null
#  minutes            :integer
#  outcome_label      :string
#  progress           :boolean          default(FALSE), not null
#  title              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  case_meeting_id    :bigint
#  case_task_id       :bigint
#  case_ticket_id     :bigint
#  case_time_entry_id :bigint
#  contact_id         :bigint
#  organization_id    :bigint
#  task_outcome_id    :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_task_reports_on_account_id                (account_id)
#  index_task_reports_on_account_id_and_closed_at  (account_id,closed_at)
#  index_task_reports_on_case_meeting_id           (case_meeting_id)
#  index_task_reports_on_case_task_id              (case_task_id)
#  index_task_reports_on_case_ticket_id            (case_ticket_id)
#  index_task_reports_on_case_time_entry_id        (case_time_entry_id)
#  index_task_reports_on_contact_id                (contact_id)
#  index_task_reports_on_organization_id           (organization_id)
#  index_task_reports_on_task_outcome_id           (task_outcome_id)
#  index_task_reports_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_meeting_id => case_meetings.id) ON DELETE => nullify
#  fk_rails_...  (case_task_id => case_tasks.id) ON DELETE => nullify
#  fk_rails_...  (case_ticket_id => case_tickets.id) ON DELETE => nullify
#  fk_rails_...  (case_time_entry_id => case_time_entries.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => nullify
#  fk_rails_...  (task_outcome_id => task_outcomes.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
class TaskReport < ApplicationRecord
  MAX_FILES = 5
  MAX_FILE_SIZE = 20.megabytes
  MAX_MINUTES = 24 * 60

  belongs_to :account
  belongs_to :case_task, optional: true
  belongs_to :case_meeting, optional: true
  belongs_to :case_ticket, optional: true
  belongs_to :contact, optional: true
  belongs_to :organization, optional: true
  belongs_to :user, optional: true
  belongs_to :task_outcome, optional: true
  belongs_to :case_time_entry, optional: true # la visita de una orden de trabajo

  has_many_attached :evidence
  has_one :time_entry, class_name: 'CaseTimeEntry', dependent: :nullify

  validates :title, presence: true
  validates :content, presence: true, length: { maximum: 5000 }
  validates :minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_MINUTES },
                      allow_nil: true
  validate :evidence_limits

  scope :pending_close, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }

  def self.build_for(item, attrs)
    report = new(attrs.merge(account_id: item.account_id, title: item.title, case_ticket_id: item.case_ticket_id,
                             contact: item.client_contact, organization: item.client_organization))
    report.public_send("#{item.model_name.singular}=", item)
    report
  end

  # Tiempo dedicado obligatorio: ajuste de la cuenta, encendido si nunca se tocó.
  def self.minutes_required?(account)
    account.custom_attributes&.fetch('report_minutes_required', true) != false
  end

  # Lo que se propone al reportar: lo estimado de la tarea menos lo ya reportado en sus
  # avances; en la tarea agendada, de la llegada a ahora o, sin llegada, lo planeado.
  def self.suggested_minutes(item)
    return remaining_minutes(item) if item.is_a?(CaseTask)
    return nil unless item.is_a?(CaseMeeting)

    from, to = item.arrived_at ? [item.arrived_at, Time.current] : [item.starts_at, item.ends_at]
    ((to - from) / 60).round.clamp(0, MAX_MINUTES) if from && to
  end

  def self.remaining_minutes(task)
    return nil unless task.estimated_minutes

    left = task.estimated_minutes - task.task_reports.closed.sum(:minutes).to_i
    left.positive? ? left : nil
  end

  # La tarea ya se concluyó (o es un avance, que se cierra al guardarse): el reporte
  # cuenta, entra a la bitácora del caso como reporte (no como nota) y su tiempo, a las
  # horas reales del caso.
  def close!(at = Time.current)
    update!(closed_at: at)
    return unless case_ticket

    log_on_case
    log_time
  end

  # Actividad reportada: algo que se hizo sin tarea detrás (con caso, contacto,
  # organización o interna). Se guarda ya cerrada.
  def activity?
    case_task_id.nil? && case_meeting_id.nil? && case_time_entry_id.nil?
  end

  # progress (avance de una tarea que sigue pendiente) | task_report (cierre) | activity_report
  def log_kind
    return 'progress' if progress?

    activity? ? 'activity_report' : 'task_report'
  end

  private

  def log_on_case
    case_ticket.case_events.create!(account_id: account_id, event_type: :task_reported, origin: :agent, actor: user,
                                    case_task_id: case_task_id,
                                    payload: { content: note_text, kind: log_kind, task_report_id: id, title: title,
                                               minutes: minutes, sequence: case_task&.sequence }.compact)
  end

  # La visita de orden ya tiene su entrada de tiempo: no se cuenta dos veces.
  def log_time
    return unless minutes.to_i.positive? && case_time_entry_id.nil? && time_entry.nil?

    case_ticket.time_entries.create!(account_id: account_id, user: user, task_report: self, source: :report, note: title,
                                     started_at: closed_at - minutes.minutes, ended_at: closed_at, minutes: minutes)
  end

  def note_text
    key = { 'progress' => 'task_reports.progress_note_title', 'activity_report' => 'task_reports.activity_note_title' }
          .fetch(log_kind, 'task_reports.note_title')
    [I18n.t(key, title: title), outcome_label, content].compact_blank.join("\n")
  end

  def evidence_limits
    errors.add(:evidence, :too_many) if evidence.size > MAX_FILES
    errors.add(:evidence, :too_big) if evidence.any? { |file| file.blob.byte_size > MAX_FILE_SIZE }
  end
end
