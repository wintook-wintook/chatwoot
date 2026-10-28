# == Schema Information
#
# Table name: crm_taxes
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  is_default :boolean          default(FALSE), not null
#  name       :string(30)       not null
#  percent    :decimal(9, 6)    default(0.0), not null
#  tax_type   :integer          default("vat"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_crm_taxes_on_account_id  (account_id)
#  index_crm_taxes_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus A0 — impuesto (IMPUESTOS de Microsip). «Exento» e «IVA 0 %» son 0 % los dos,
# pero el CFDI los distingue: por eso el exento es su propio tipo.
class CrmTax < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  enum tax_type: { vat: 1, vat_exempt: 2, vat_withholding: 3, isr_withholding: 4, ieps: 5 }

  validates :name, length: { maximum: 30 }
  validates :tax_type, presence: true
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:tax_type, :name) }

  def withholding?
    vat_withholding? || isr_withholding?
  end
end
