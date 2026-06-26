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
#  idx_unique_native_knowledge_sources                    (account_id,source_type) UNIQUE WHERE ((source_type)::text = ANY ((ARRAY['canned_response'::character varying, 'article'::character varying])::text[]))
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

  # Tipos cuyo nombre direcciona una directiva del bot: @buscar_foro(nombre) y
  # {{doc:nombre}}. Para estos el nombre debe ser único por cuenta. Las fuentes
  # nativas (canned_response/article) se autogestionan con nombre localizado fijo y
  # quedan fuera (su recreación vía create_or_find_by no debe disparar RecordInvalid).
  ADDRESSABLE_BY_NAME = %w[discourse google_doc google_sheet].freeze

  has_many :google_sheet_rows, dependent: :destroy

  validates :source_type, presence: true, inclusion: { in: %w[canned_response discourse article google_doc google_sheet] }
  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }, if: :addressable_by_name?

  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(source_type: type) }

  def addressable_by_name?
    ADDRESSABLE_BY_NAME.include?(source_type)
  end
end
