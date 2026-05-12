# @knowledge_sources
# Fuente de conocimiento configurada por cuenta.
# source_type: 'canned_response' | 'discourse'
class KnowledgeSource < ApplicationRecord
  belongs_to :account
  has_many :knowledge_items, dependent: :destroy

  validates :source_type, presence: true, inclusion: { in: %w[canned_response discourse] }
  validates :name, presence: true

  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(source_type: type) }
end
