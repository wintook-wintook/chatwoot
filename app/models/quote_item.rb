# == Schema Information
#
# Table name: quote_items
#
#  id               :bigint           not null, primary key
#  description      :string           not null
#  discount_percent :decimal(5, 2)    default(0.0), not null
#  kind             :integer
#  position         :integer          default(0), not null
#  quantity         :decimal(12, 2)   default(1.0), not null
#  tax_percent      :decimal(5, 2)    default(0.0), not null
#  total            :decimal(14, 2)   default(0.0), not null
#  unit             :string
#  unit_price       :decimal(14, 2)   default(0.0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  catalog_item_id  :bigint
#  quote_id         :bigint           not null
#
# Indexes
#
#  index_quote_items_on_account_id       (account_id)
#  index_quote_items_on_catalog_item_id  (catalog_item_id)
#  index_quote_items_on_quote_id         (quote_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (catalog_item_id => catalog_items.id) ON DELETE => nullify
#  fk_rails_...  (quote_id => quotes.id) ON DELETE => cascade
#

# Plan-Catalogo-Cotizaciones V1 — partida de una cotización: del catálogo o libre.
# total = cantidad × precio − descuento (%) + impuesto (%).
class QuoteItem < ApplicationRecord
  belongs_to :account
  belongs_to :quote, inverse_of: :items
  belongs_to :catalog_item, optional: true

  enum kind: { product: 0, service: 1, part: 2 }

  before_validation :compute_total

  validates :description, presence: true, length: { maximum: 500 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, :tax_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def net_amount
    (quantity.to_d * unit_price.to_d * (1 - (discount_percent.to_d / 100))).round(2)
  end

  def tax_amount
    (net_amount * tax_percent.to_d / 100).round(2)
  end

  private

  def compute_total
    self.total = net_amount + tax_amount
  end
end
