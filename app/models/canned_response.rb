# == Schema Information
#
# Table name: canned_responses
#
#  id                :integer          not null, primary key
#  content           :text
#  content_full      :boolean          default(FALSE), not null
#  content_is_prompt :boolean          default(FALSE), not null
#  content_prompts   :text
#  menu              :boolean          default(FALSE), not null
#  opcion            :bigint           default(0), not null
#  short_code        :string
#  url_content       :boolean          default(FALSE), not null
#  url_short_code    :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#

class CannedResponse < ApplicationRecord
  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account

  # @knowledge_sources — sincroniza embeddings al crear/actualizar/eliminar
  # proyecto@predefinidas_prompt — solo se vectoriza lo que se busca (el nombre y el
  # contenido). Cambiar únicamente el prompt propio no toca la búsqueda, y volver a pedir
  # el embedding sería una llamada a OpenAI por nada.
  #
  # Un solo callback: registrar el mismo método dos veces (on: :create y on: :update) hace
  # que Rails se quede con el último, y las respuestas nuevas no se vectorizarían nunca.
  after_commit :sync_knowledge_embedding, on: %i[create update], if: :needs_embedding?
  after_commit :destroy_knowledge_embedding, on: :destroy

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  private

  def needs_embedding?
    previously_new_record? || saved_change_to_short_code? || saved_change_to_content?
  end

  # @knowledge_sources
  def sync_knowledge_embedding
    KnowledgeItemSyncJob.perform_later(
      action: 'upsert',
      source_type: 'canned_response',
      source_id: id,
      account_id: account_id
    )
  end

  def destroy_knowledge_embedding
    KnowledgeItemSyncJob.perform_later(
      action: 'destroy',
      source_type: 'canned_response',
      source_id: id,
      account_id: account_id
    )
  end
end
