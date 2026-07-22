# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tasks
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  description     :text
#  due_at          :datetime
#  position        :integer          default(0), not null
#  status          :integer          default("pending"), not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  assignee_id     :bigint
#  case_ticket_id  :bigint           not null
#  completed_by_id :bigint
#
# Indexes
#
#  index_case_tasks_on_account_id                   (account_id)
#  index_case_tasks_on_assignee_id                  (assignee_id)
#  index_case_tasks_on_case_ticket_id               (case_ticket_id)
#  index_case_tasks_on_case_ticket_id_and_position  (case_ticket_id,position)
#  index_case_tasks_on_completed_by_id              (completed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#  fk_rails_...  (completed_by_id => users.id) ON DELETE => nullify
#

# @tickets_cases — Tarea/subtarea de un ticket (osTicket "Tasks").
class CaseTask < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket
  belongs_to :assignee, class_name: 'User', optional: true
  # @tickets_cases P4 — quién marcó la tarea como completada (osTicket lo audita).
  belongs_to :completed_by, class_name: 'User', optional: true

  enum status: { pending: 0, done: 1 }

  validates :title, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :id) }

  # @tickets_cases P4 — el "quién/cuándo" se deriva del cambio de estado, no se
  # acepta del cliente: así no hay forma de falsear la firma desde la API.
  before_save :track_completion, if: :will_save_change_to_status?

  private

  def track_completion
    if done?
      self.completed_at    = Time.current
      self.completed_by_id = Current.user&.id
    else
      self.completed_at    = nil
      self.completed_by_id = nil
    end
  end
end
