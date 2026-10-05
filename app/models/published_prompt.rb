# == Schema Information
#
# Table name: published_prompts
#
#  id                   :bigint           not null, primary key
#  ai_context           :text
#  category             :string
#  description          :text
#  downloads_count      :integer          default(0), not null
#  keyword_actions      :jsonb            not null
#  objective            :string           not null
#  prompt               :text             not null
#  published_at         :datetime
#  requirements         :jsonb            not null
#  settings             :jsonb            not null
#  status               :string           default("published"), not null
#  title                :string           not null
#  version              :integer          default(1), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_published_prompts_on_account_id            (account_id)
#  index_published_prompts_on_status_and_category   (status,category)
#  index_published_prompts_on_tracking_template_id  (tracking_template_id) UNIQUE
#  index_published_prompts_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
# ================================================================================
# proyecto@publicar_prompts
# ================================================================================
# Modelo: PublishedPrompt
# Descripción: foto del prompt de un Agente IA que un usuario autorizado publica para
# que otras cuentas la bajen como agente propio. Es una COPIA: lo que el autor cambie
# en su agente no llega aquí hasta que vuelva a publicar (version + 1), y lo que cambie
# la cuenta que la bajó nunca toca esto. Plan: docs/publicar_prompts_plan.md
# ================================================================================

class PublishedPrompt < ApplicationRecord
  STATUSES = %w[published unpublished].freeze
  CATEGORIES = %w[ventas cobranza soporte agenda atencion otros].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :tracking_template, optional: true, inverse_of: :publication

  # Los agentes que otras cuentas crearon al bajarla.
  has_many :installed_templates, class_name: 'TrackingTemplate', dependent: :nullify, inverse_of: :published_prompt

  validates :title, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :objective, presence: true
  validates :prompt, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :tracking_template_id, uniqueness: true, allow_nil: true

  scope :published, -> { where(status: 'published') }
  scope :by_category, ->(category) { where(category: category) }
  scope :search, ->(query) { where('title ILIKE :q OR description ILIKE :q', q: "%#{sanitize_sql_like(query)}%") }
  scope :ordered, -> { order(published_at: :desc) }

  def published?
    status == 'published'
  end
end
