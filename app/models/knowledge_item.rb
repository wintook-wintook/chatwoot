# @knowledge_sources
# Ítem vectorizado de la base de conocimiento.
# Representa un fragmento de contenido indexado con su embedding de OpenAI.
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
