# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tasks
#
#  id             :bigint           not null, primary key
#  due_at         :datetime
#  position       :integer          default(0), not null
#  status         :integer          default("pending"), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  assignee_id    :bigint
#  case_ticket_id :bigint           not null
#
# Indexes
#
#  index_case_tasks_on_account_id                   (account_id)
#  index_case_tasks_on_assignee_id                  (assignee_id)
#  index_case_tasks_on_case_ticket_id               (case_ticket_id)
#  index_case_tasks_on_case_ticket_id_and_position  (case_ticket_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#

# @tickets_cases — Tarea/subtarea de un ticket (osTicket "Tasks").
class CaseTask < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket
  belongs_to :assignee, class_name: 'User', optional: true

  enum status: { pending: 0, done: 1 }

  validates :title, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :id) }
end
