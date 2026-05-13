# == Schema Information
#
# Table name: knowledge_sources
#
#  id                :bigint           not null, primary key
#  config            :jsonb
#  last_synced_at    :datetime
#  name              :string           not null
#  source_type       :string           not null
#  status            :string           default("active")
#  sync_jobs_pending :integer          default(0), not null
#  sync_status       :string           default("idle"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_knowledge_sources_on_account_id                  (account_id)
#  index_knowledge_sources_on_account_id_and_source_type  (account_id,source_type)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KnowledgeSource < ApplicationRecord
  belongs_to :account
  has_many :knowledge_items, dependent: :destroy

  validates :source_type, presence: true, inclusion: { in: %w[canned_response discourse] }
  validates :name, presence: true

  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(source_type: type) }
end
