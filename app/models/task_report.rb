# == Schema Information
#
# Table name: task_reports
#
#  id                 :bigint           not null, primary key
#  closed_at          :datetime
#  content            :text             not null
#  outcome_label      :string
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

  validates :title, presence: true
  validates :content, presence: true, length: { maximum: 5000 }
  validate :evidence_limits

  scope :pending_close, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }

  def self.build_for(item, attrs)
    report = new(attrs.merge(account_id: item.account_id, title: item.title, case_ticket_id: item.case_ticket_id,
                             contact: item.client_contact, organization: item.client_organization))
    report.public_send("#{item.model_name.singular}=", item)
    report
  end

  # La tarea ya se concluyó: el reporte cuenta, y entra a la bitácora del caso.
  def close!
    update!(closed_at: Time.current)
    log_on_case if case_ticket
  end

  private

  def log_on_case
    case_ticket.case_events.create!(account_id: account_id, event_type: :internal_note, origin: :agent, actor: user,
                                    case_task_id: case_task_id, payload: { content: note_text })
  end

  def note_text
    [I18n.t('task_reports.note_title', title: title), outcome_label, content].compact_blank.join("\n")
  end

  def evidence_limits
    errors.add(:evidence, :too_many) if evidence.size > MAX_FILES
    errors.add(:evidence, :too_big) if evidence.any? { |file| file.blob.byte_size > MAX_FILE_SIZE }
  end
end
