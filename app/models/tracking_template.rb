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
#  id                   :bigint           not null, primary key
#  ai_context           :text
#  complementary_prompt :text
#  name                 :string           not null
#  objective            :string           not null
#  tags                 :json
#  whatsapp_templates   :json
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  inbox_id             :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_tracking_templates_on_account_id           (account_id)
#  index_tracking_templates_on_account_id_and_name  (account_id,name) UNIQUE
#  index_tracking_templates_on_inbox_id             (inbox_id)
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

  scope :by_tag, ->(tag) { where("tags @> ?", [tag].to_json) }
  scope :by_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }
  scope :ordered, -> { order(updated_at: :desc) }

  before_save :ensure_arrays

  private

  def ensure_arrays
    self.whatsapp_templates = [] unless whatsapp_templates.is_a?(Array)
    self.tags = [] unless tags.is_a?(Array)
  end
end
