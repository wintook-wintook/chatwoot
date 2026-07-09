# == Schema Information
#
# Table name: knowledge_items
#
#  id                  :bigint           not null, primary key
#  chunk_index         :integer          default(0), not null
#  content             :text             not null
#  embedding           :vector(1536)
#  metadata            :jsonb
#  source_type         :string           not null
#  title               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  knowledge_source_id :bigint           not null
#  source_id           :integer          not null
#
# Indexes
#
#  idx_knowledge_items_source                    (account_id,source_type,source_id,chunk_index) UNIQUE
#  index_knowledge_items_on_account_id           (account_id)
#  index_knowledge_items_on_knowledge_source_id  (knowledge_source_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (knowledge_source_id => knowledge_sources.id)
#
class KnowledgeItem < ApplicationRecord
  belongs_to :account
  belongs_to :knowledge_source

  has_neighbors :embedding

  validates :content, presence: true
  validates :source_type, presence: true
  validates :source_id, presence: true

  scope :by_source_type, ->(type) { where(source_type: type) }

  def self.search_by_embedding(embedding_vector, limit: 5, threshold: 0.7)
    nearest_neighbors(:embedding, embedding_vector, distance: 'cosine')
      .limit(limit * 3)
      .select { |item| item.neighbor_distance <= (1 - threshold) }
      .first(limit)
  end
end
