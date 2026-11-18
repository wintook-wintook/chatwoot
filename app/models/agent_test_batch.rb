# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_test_batches
#
#  id                   :bigint           not null, primary key
#  day                  :date
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  created_by_id        :bigint
#  tracking_template_id :bigint
#
# Indexes
#
#  index_agent_test_batches_on_account_id                    (account_id)
#  index_agent_test_batches_on_created_by_id                 (created_by_id)
#  index_agent_test_batches_on_tracking_template_id          (tracking_template_id)
#  index_agent_test_batches_on_tracking_template_id_and_day  (tracking_template_id,day)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#
class AgentTestBatch < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  # El lote «Correcciones · <agente>» que se arma solo con cada 👎 (AgentTester::AutoCase).
  belongs_to :tracking_template, optional: true
  has_many :cases, class_name: 'AgentTestCase', dependent: :destroy
  has_many :runs, class_name: 'AgentTestRun', dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
end
