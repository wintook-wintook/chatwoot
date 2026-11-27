# == Schema Information
#
# Table name: crm_quote_taxes
#
#  id                :bigint           not null, primary key
#  amount            :decimal(18, 6)   default(0.0), not null
#  base_amount       :decimal(15, 2)   default(0.0), not null
#  gross_amount      :decimal(18, 6)   default(0.0), not null
#  gross_base_amount :decimal(15, 2)   default(0.0), not null
#  name              :string(30)       not null
#  percent           :decimal(9, 6)    default(0.0), not null
#  position          :integer          default(0), not null
#  tax_type          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  quote_id          :bigint           not null
#  tax_id            :bigint
#
# Indexes
#
#  index_crm_quote_taxes_on_account_id           (account_id)
#  index_crm_quote_taxes_on_quote_id             (quote_id)
#  index_crm_quote_taxes_on_quote_id_and_tax_id  (quote_id,tax_id) UNIQUE
#  index_crm_quote_taxes_on_tax_id               (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (quote_id => crm_quotes.id) ON DELETE => cascade
#  fk_rails_...  (tax_id => crm_taxes.id) ON DELETE => nullify
#

# CrmZeus Q3.1 — impuesto del documento (IMPUESTOS_DCDOCTOS_PDV): lo acumulado de un impuesto en las
# partidas de la cotización (addTaxes de CRMZeus). Lo escribe Crm::QuoteTotals; no se captura.
class CrmQuoteTax < ApplicationRecord
  belongs_to :account
  belongs_to :quote, class_name: 'CrmQuote', inverse_of: :taxes
  belongs_to :tax, class_name: 'CrmTax', optional: true

  # Mismos valores que CrmTax.tax_type.
  enum tax_type: CrmTax.tax_types

  def withholding?
    vat_withholding? || isr_withholding?
  end
end
