# == Schema Information
#
# Table name: crm_countries
#
#  id           :bigint           not null, primary key
#  abbreviation :string(10)
#  is_default   :boolean          default(FALSE), not null
#  iso_code     :string(3)
#  name         :string(50)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_crm_countries_on_account_id  (account_id)
#  index_crm_countries_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus O0 — país → estado → ciudad, por cuenta (PAISES/ESTADOS/CIUDADES de Microsip).
# México y sus 32 estados se precargan con Crm::DefaultCatalogs.
class CrmCountry < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  has_many :states, class_name: 'CrmState', foreign_key: :country_id, inverse_of: :country, dependent: :destroy

  validates :name, length: { maximum: 50 }

  scope :ordered, -> { order(is_default: :desc, name: :asc) }
end
