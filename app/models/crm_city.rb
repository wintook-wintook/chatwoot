# == Schema Information
#
# Table name: crm_cities
#
#  id         :bigint           not null, primary key
#  name       :string(50)       not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  state_id   :bigint           not null
#
# Indexes
#
#  index_crm_cities_on_account_id  (account_id)
#  index_crm_cities_on_state_id    (state_id)
#  index_crm_cities_unique_name    (state_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (state_id => crm_states.id) ON DELETE => cascade
#

# CrmZeus O0 — ciudad de un estado. Se dan de alta al vuelo desde el formulario de la
# organización, como en CRMZeus.
class CrmCity < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry unique_within: [:state_id], default_within: [:state_id]

  belongs_to :state, class_name: 'CrmState', inverse_of: :cities
  has_one :country, through: :state

  before_validation { self.account_id ||= state&.account_id }

  validates :name, length: { maximum: 50 }

  scope :ordered, -> { order(:name) }

  # «Torreón, COA, México» (como el selector de CRMZeus).
  def full_name
    [name, state&.abbreviation.presence || state&.name, state&.country&.name].compact.join(', ')
  end
end
