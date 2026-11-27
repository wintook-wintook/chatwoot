# == Schema Information
#
# Table name: crm_units
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  is_default :boolean          default(FALSE), not null
#  name       :string(20)       not null
#  sat_key    :string(3)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_crm_units_on_account_id  (account_id)
#  index_crm_units_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus A0 — unidad de venta (UNIDADES_VENTA de Microsip). En Microsip el artículo
# guardaba el texto y se elegía de las unidades SAT; aquí es catálogo propio con la
# clave SAT opcional (H87 pieza, E48 servicio, KGM kilogramo…).
class CrmUnit < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  before_validation { self.sat_key = sat_key.to_s.strip.upcase.presence }

  validates :name, length: { maximum: 20 }
  validates :sat_key, format: { with: /\A[A-Z0-9]{1,3}\z/ }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
