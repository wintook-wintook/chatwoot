# == Schema Information
#
# Table name: crm_currencies
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  amount_in_words     :string(50)
#  fixed_exchange_rate :decimal(14, 6)
#  is_default          :boolean          default(FALSE), not null
#  is_local            :boolean          default(FALSE), not null
#  iso_code            :string(3)
#  name                :string(50)       not null
#  symbol              :string(10)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_crm_currencies_on_account_id  (account_id)
#  index_crm_currencies_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus O0 — monedas (MONEDAS de Microsip). `fixed_exchange_rate` vacío = se usa el
# tipo de cambio del día (cuando exista); la moneda local siempre vale 1.
class CrmCurrency < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  before_validation :normalize_codes

  validates :name, length: { maximum: 50 }
  validates :iso_code, format: { with: /\A[A-Z]{3}\z/ }, allow_nil: true
  validates :fixed_exchange_rate, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(is_local: :desc, name: :asc) }

  private

  def normalize_codes
    self.iso_code = iso_code.to_s.strip.upcase.presence
    self.symbol = symbol.to_s.strip.presence
    self.fixed_exchange_rate = nil if is_local?
  end
end
