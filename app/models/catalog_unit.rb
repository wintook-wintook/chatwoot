# == Schema Information
#
# Table name: catalog_units
#
#  id           :bigint           not null, primary key
#  abbreviation :string           not null
#  active       :boolean          default(TRUE), not null
#  name         :string           not null
#  sat_code     :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_catalog_units_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# Productos y servicios › Parámetros — una unidad de medida (Pieza «pza», Hora «hr»…) con su clave SAT
# opcional (H87, HUR…). El producto guarda su unidad y, como copia, la abreviatura en catalog_items.unit
# (lo que pasa a las partidas de cotizaciones y órdenes). No se borra si la usa un producto: se desactiva.
class CatalogUnit < ApplicationRecord
  # Las que trae la cuenta la primera vez (CatalogParameters::Setup).
  DEFAULTS = [%w[Pieza pza H87], %w[Servicio serv E48], %w[Hora hr HUR], %w[Día día DAY], %w[Kilogramo kg KGM],
              %w[Metro m MTR], %w[Litro l LTR], %w[Caja caja XBX], %w[Juego jgo SET], %w[Paquete paq XPK]].freeze

  belongs_to :account
  has_many :catalog_items, dependent: :restrict_with_error

  before_validation :normalize
  validates :name, presence: true, length: { maximum: 60 }
  validates :abbreviation, presence: true, length: { maximum: 20 }
  validates :sat_code, length: { maximum: 10 }, allow_nil: true
  validate :abbreviation_unique
  after_update :sync_items, if: :saved_change_to_abbreviation?

  scope :ordered, -> { order(Arel.sql('LOWER(name)')) }

  def in_use? = catalog_items.exists?

  # La de la cuenta que se llama o se abrevia así (sin importar mayúsculas).
  def self.matching(text)
    value = text.to_s.squish.downcase
    where('LOWER(abbreviation) = :v OR LOWER(name) = :v', v: value).first
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.abbreviation = abbreviation.to_s.squish.presence || name
    self.sat_code = sat_code.to_s.strip.upcase.presence
  end

  def abbreviation_unique
    same = account&.catalog_units&.where('LOWER(abbreviation) = ?', abbreviation.to_s.downcase)
    same = same.where.not(id: id) if persisted?
    errors.add(:abbreviation, :taken) if same&.exists?
  end

  def sync_items
    catalog_items.update_all(unit: abbreviation, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
