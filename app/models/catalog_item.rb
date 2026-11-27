# == Schema Information
#
# Table name: catalog_items
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(TRUE), not null
#  category             :string
#  cost                 :decimal(14, 2)
#  currency             :string(3)        default("MXN"), not null
#  description          :text
#  duration_minutes     :integer
#  kind                 :integer          default("product"), not null
#  name                 :string           not null
#  price                :decimal(14, 2)   default(0.0), not null
#  price_includes_tax   :boolean          default(FALSE), not null
#  sat_code             :string
#  sku                  :string
#  unit                 :string
#  withholding_rate_ids :bigint           default([]), not null, is an Array
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  catalog_category_id  :bigint
#  catalog_unit_id      :bigint
#  tax_rate_id          :bigint
#
# Indexes
#
#  index_catalog_items_on_account_id                      (account_id)
#  index_catalog_items_on_account_id_and_active_and_kind  (account_id,active,kind)
#  index_catalog_items_on_account_id_and_sku              (account_id,sku) UNIQUE WHERE (sku IS NOT NULL)
#  index_catalog_items_on_catalog_category_id             (catalog_category_id)
#  index_catalog_items_on_catalog_unit_id                 (catalog_unit_id)
#  index_catalog_items_on_tax_rate_id                     (tax_rate_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (catalog_category_id => catalog_categories.id)
#  fk_rails_...  (catalog_unit_id => catalog_units.id)
#  fk_rails_...  (tax_rate_id => tax_rates.id)
#

# Plan-Catalogo-Cotizaciones C1 — un producto, servicio o refacción del catálogo
# de la cuenta. Lo usan las cotizaciones (Ventas) y los materiales de las órdenes
# de trabajo (Servicio). No se borra: se desactiva, para no romper lo que ya lo usa.
# Categoría, unidad e impuesto salen de las listas de la cuenta (CatalogItemParameters).
class CatalogItem < ApplicationRecord
  KIND_ALIASES = {
    'producto' => 'product', 'servicio' => 'service', 'refaccion' => 'part', 'refacción' => 'part'
  }.freeze

  belongs_to :account
  # La foto del producto: la manda el agente de prospectos al recomendarlo (Motor2::Skills::Recommend).
  has_one_attached :image
  IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_IMAGE = 5.megabytes

  enum kind: { product: 0, service: 1, part: 2 }

  before_validation :normalize
  include CatalogItemParameters
  after_update :update_contract_prices, if: -> { saved_change_to_price? || saved_change_to_currency? }

  validates :name, presence: true, length: { maximum: 200 }
  validates :sku, uniqueness: { scope: :account_id }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  # Cuánto dura el servicio (minutos): las citas de servicio de «Atención a clientes» ocupan esa duración en la agenda.
  validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than_or_equal_to: 720 }, allow_nil: true
  validate :image_ok, if: -> { image.attached? }

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

  # Los contratos que siguen el precio de este producto (Contract#fill_catalog_price).
  def update_contract_prices
    Contract.where(catalog_item_id: id, price_from_catalog: true)
            .update_all(price: price, currency: currency, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def account_currency
    (account && CaseSetting.for_account(account).default_currency) || 'MXN'
  end

  # PNG, JPG o WEBP de hasta 5 MB (WhatsApp no manda otras).
  def image_ok
    errors.add(:image, 'debe ser PNG, JPG o WEBP') unless IMAGE_TYPES.include?(image.blob.content_type)
    errors.add(:image, 'debe pesar menos de 5 MB') if image.blob.byte_size > MAX_IMAGE
  end
end
