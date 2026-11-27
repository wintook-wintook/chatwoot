# == Schema Information
#
# Table name: crm_lookups
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  is_default :boolean          default(FALSE), not null
#  kind       :integer          not null
#  name       :string(100)      not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_crm_lookups_on_account_id  (account_id)
#  index_crm_lookups_unique_name    (account_id, kind, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus O0 — catálogos de organizaciones que son solo un nombre (CALIFICACIONES, GIROS,
# ORIGENES de CRMZeus; TIPOS_CLIENTES, ZONAS_CLIENTES, COBRADORES de Microsip).
# No se borran si ya se usan: se desactivan.
class CrmLookup < ApplicationRecord
  include CrmCatalogEntry

  # price_list / line_group: catálogos de artículos (listas de precios, grupos de líneas).
  enum kind: { customer_type: 1, rating: 2, industry: 3, origin: 4, zone: 5, collector: 6, price_list: 7, line_group: 8 }

  crm_catalog_entry unique_within: %i[account_id kind], default_within: %i[account_id kind]

  validates :kind, presence: true
  validates :name, length: { maximum: 100 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
