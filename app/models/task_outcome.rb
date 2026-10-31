# == Schema Information
#
# Table name: task_outcomes
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  label      :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_task_outcomes_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class TaskOutcome < ApplicationRecord
  DEFAULTS = ['Logrado', 'No contestó', 'Reprogramar', 'No se pudo'].freeze

  belongs_to :account

  validates :label, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(:position, :id) }

  def self.ensure_defaults_for(account)
    seed_defaults(account) if account.task_outcomes.none?
    account.task_outcomes.ordered
  end

  def self.seed_defaults(account)
    DEFAULTS.each_with_index { |label, position| account.task_outcomes.create!(label: label, position: position) }
  end
end
