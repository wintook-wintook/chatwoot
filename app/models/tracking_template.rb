# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Modelo: TrackingTemplate
# Descripción: Plantillas reutilizables para configuraciones de seguimiento
# Asociaciones: account, inbox (optional), user (optional)
# ================================================================================

# == Schema Information
#
# Table name: tracking_templates
#
#  id                       :bigint           not null, primary key
#  ai_context               :text
#  calendar_integration_ids :jsonb            not null
#  complementary_prompt     :text
#  keyword_actions          :jsonb            not null
#  name                     :string           not null
#  objective                :string           not null
#  retry_interval_unit      :string           default("days")
#  retry_interval_value     :integer          default(1)
#  tags                     :json
#  whatsapp_templates       :json
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  inbox_id                 :bigint
#  kbase_hook_id            :integer
#  user_id                  :bigint
#
# Indexes
#
#  index_tracking_templates_on_account_id           (account_id)
#  index_tracking_templates_on_account_id_and_name  (account_id,name) UNIQUE
#  index_tracking_templates_on_inbox_id             (inbox_id)
#  index_tracking_templates_on_kbase_hook_id        (kbase_hook_id)
#  index_tracking_templates_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (user_id => users.id)
#

class TrackingTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :user, optional: true

  validates :name, presence: true, length: { minimum: 2, maximum: 100 },
                   uniqueness: { scope: :account_id, case_sensitive: false }
  validates :objective, presence: true, length: { minimum: 5, maximum: 500 }
  # proyecto@automatizacion_tracking: intervalo entre intentos (opcional, mismo comportamiento que ContactTracking)
  validates :retry_interval_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :retry_interval_unit, inclusion: { in: %w[minutes hours days] }, allow_nil: true
  # proyecto@contact_tracking: palabras clave de acción
  validate :keyword_actions_valid_structure

  scope :by_tag, ->(tag) { where("tags @> ?", [tag].to_json) }
  scope :by_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }
  scope :ordered, -> { order(updated_at: :desc) }

  before_save :ensure_arrays

  private

  def ensure_arrays
    self.whatsapp_templates = [] unless whatsapp_templates.is_a?(Array)
    self.tags               = [] unless tags.is_a?(Array)
    self.keyword_actions    = [] unless keyword_actions.is_a?(Array)
  end

  def keyword_actions_valid_structure
    return unless keyword_actions.is_a?(Array)

    keyword_actions.each do |ka|
      unless ka.is_a?(Hash) &&
             ka['keyword'].to_s.strip.present? &&
             %w[cancel pause].include?(ka['action'].to_s) &&
             %w[incoming outgoing both].include?(ka['direction'].to_s)
        errors.add(:keyword_actions, 'contiene una entrada con formato inválido')
        break
      end
    end
  end
end
