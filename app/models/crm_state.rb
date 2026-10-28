# == Schema Information
#
# Table name: crm_states
#
#  id           :bigint           not null, primary key
#  abbreviation :string(10)
#  name         :string(50)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  country_id   :bigint           not null
#
# Indexes
#
#  index_crm_states_on_account_id  (account_id)
#  index_crm_states_on_country_id  (country_id)
#  index_crm_states_unique_name    (country_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (country_id => crm_countries.id) ON DELETE => cascade
#

# CrmZeus O0 — estado de un país (`abbreviation` = clave c_Estado del SAT en México).
class CrmState < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry unique_within: [:country_id], default_within: [:country_id]

  belongs_to :country, class_name: 'CrmCountry', inverse_of: :states
  has_many :cities, class_name: 'CrmCity', foreign_key: :state_id, inverse_of: :state, dependent: :destroy

  before_validation { self.account_id ||= country&.account_id }

  validates :name, length: { maximum: 50 }
  validate :country_belongs_to_account

  scope :ordered, -> { order(:name) }

  private

  def country_belongs_to_account
    errors.add(:country, 'no pertenece a la cuenta') if country && country.account_id != account_id
  end
end
