# == Schema Information
#
# Table name: case_work_logs
#
#  id             :bigint           not null, primary key
#  content        :text
#  kind           :integer          default("note"), not null
#  tag            :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  case_ticket_id :bigint           not null
#  user_id        :bigint
#
# Indexes
#
#  index_case_work_logs_on_account_id      (account_id)
#  index_case_work_logs_on_case_ticket_id  (case_ticket_id)
#  index_case_work_logs_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

# Plan-Trabajo-Campo R1 — una entrada de la bitácora de la orden de trabajo: lo
# que se hizo (nota) o una foto/archivo, con su etiqueta «antes» o «después».
class CaseWorkLog < ApplicationRecord
  MAX_FILE_SIZE = 20.megabytes

  belongs_to :account
  belongs_to :case_ticket
  belongs_to :user, optional: true

  has_one_attached :file

  enum kind: { note: 0, photo: 1, document: 2 }
  enum tag: { before: 0, after: 1 }, _prefix: :tag

  validates :content, presence: true, if: :note?
  validate :file_present, unless: :note?

  scope :ordered, -> { order(:created_at, :id) }

  private

  def file_present
    return errors.add(:file, 'es obligatorio') unless file.attached?

    errors.add(:file, 'es muy grande (máximo 20 MB)') if file.blob.byte_size > MAX_FILE_SIZE
  end
end
