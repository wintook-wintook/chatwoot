# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_test_cases
#
#  id                  :bigint           not null, primary key
#  bad_reply           :text
#  expected            :text
#  messages            :jsonb            not null
#  name                :string           not null
#  origin              :string           default("correction"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  agent_test_batch_id :bigint           not null
#
# Indexes
#
#  index_agent_test_cases_on_account_id           (account_id)
#  index_agent_test_cases_on_agent_test_batch_id  (agent_test_batch_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (agent_test_batch_id => agent_test_batches.id)
#
class AgentTestCase < ApplicationRecord
  MAX_MESSAGES = 8
  ORIGINS = %w[correction manual].freeze # de un 👎 | guardada a mano desde el probador

  belongs_to :account
  belongs_to :batch, class_name: 'AgentTestBatch', foreign_key: :agent_test_batch_id, inverse_of: :cases

  validates :name, presence: true, length: { maximum: 120 }
  validates :origin, inclusion: { in: ORIGINS }
  validate :messages_present

  private

  def messages_present
    errors.add(:messages, 'necesita al menos un mensaje del cliente') if Array(messages).compact_blank.empty?
  end
end
