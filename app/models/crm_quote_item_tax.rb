# == Schema Information
#
# Table name: crm_quote_item_taxes
#
#  id                :bigint           not null, primary key
#  amount            :decimal(18, 6)   default(0.0), not null
#  base_amount       :decimal(15, 2)   default(0.0), not null
#  gross_amount      :decimal(18, 6)   default(0.0), not null
#  gross_base_amount :decimal(15, 2)   default(0.0), not null
#  name              :string(30)       not null
#  percent           :decimal(9, 6)    default(0.0), not null
#  tax_type          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  item_id           :bigint           not null
#  tax_id            :bigint
#
# Indexes
#
#  index_crm_quote_item_taxes_on_account_id          (account_id)
#  index_crm_quote_item_taxes_on_item_id             (item_id)
#  index_crm_quote_item_taxes_on_item_id_and_tax_id  (item_id,tax_id) UNIQUE
#  index_crm_quote_item_taxes_on_tax_id              (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (item_id => crm_quote_items.id) ON DELETE => cascade
#  fk_rails_...  (tax_id => crm_taxes.id) ON DELETE => nullify
#

# CrmZeus Q0 — impuesto o retención de una partida (IMPUESTOS_DCDOCTOS_PDV_DET), con nombre,
# tipo y % copiados del catálogo al cotizar. `base_amount` es el importe neto de la partida y
# `amount` lo que resulta de aplicarle el % (con el descuento extra, si es por porcentaje).
class CrmQuoteItemTax < ApplicationRecord
  belongs_to :account
  belongs_to :item, class_name: 'CrmQuoteItem', inverse_of: :item_taxes
  belongs_to :tax, class_name: 'CrmTax', optional: true

  enum tax_type: CrmTax.tax_types

  validates :name, presence: true, length: { maximum: 30 }
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def withholding?
    vat_withholding? || isr_withholding?
  end
end
