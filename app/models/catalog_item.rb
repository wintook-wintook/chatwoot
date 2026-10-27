# == Schema Information
#
# Table name: catalog_items
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  category    :string
#  cost        :decimal(14, 2)
#  currency    :string(3)        default("MXN"), not null
#  description :text
#  kind        :integer          default("product"), not null
#  name        :string           not null
#  price       :decimal(14, 2)   default(0.0), not null
#  sku         :string
#  unit        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_catalog_items_on_account_id                      (account_id)
#  index_catalog_items_on_account_id_and_active_and_kind  (account_id,active,kind)
#  index_catalog_items_on_account_id_and_sku              (account_id,sku) UNIQUE WHERE (sku IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# Plan-Catalogo-Cotizaciones C1 — un producto, servicio o refacción del catálogo
# de la cuenta. Lo usan las cotizaciones (Ventas) y los materiales de las órdenes
# de trabajo (Servicio). No se borra: se desactiva, para no romper lo que ya lo usa.
class CatalogItem < ApplicationRecord
  KIND_ALIASES = {
    'producto' => 'product', 'servicio' => 'service', 'refaccion' => 'part', 'refacción' => 'part'
  }.freeze

  belongs_to :account

  enum kind: { product: 0, service: 1, part: 2 }

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 200 }
  validates :sku, uniqueness: { scope: :account_id }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def self.search(term)
    return all if term.blank?

    like = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where('catalog_items.name ILIKE :q OR catalog_items.sku ILIKE :q', q: like)
  end

  # «Servicio», «refacción», «product»… → la clave del enum (nil si no se reconoce).
  def self.kind_from(value)
    key = value.to_s.strip.downcase
    key = KIND_ALIASES.fetch(key, key)
    kinds.key?(key) ? key : nil
  end

  private

  def normalize
    self.name = name.to_s.strip
    %i[sku category unit].each { |field| self[field] = self[field].to_s.strip.presence }
    self.currency = currency.to_s.strip.upcase.presence || account_currency
  end

  def account_currency
    (account && CaseSetting.for_account(account).default_currency) || 'MXN'
  end
end
