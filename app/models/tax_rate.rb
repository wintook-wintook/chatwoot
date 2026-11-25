# == Schema Information
#
# Table name: tax_rates
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  exempt     :boolean          default(FALSE), not null
#  is_default :boolean          default(FALSE), not null
#  kind       :integer          default("transfer"), not null
#  name       :string           not null
#  percent    :decimal(7, 4)    default(0.0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_tax_rates_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# Productos y servicios › Parámetros — un impuesto de la cuenta:
#   transfer     trasladado (IVA 16 %, IVA 8 % frontera, IVA 0 %, Exento…). Uno es «por omisión»: lo usan los
#                productos sin impuesto propio y las partidas libres; se copia a case_settings.default_tax_percent
#   withholding  retención (Ret. IVA 10.6667 %, Ret. ISR 10 %…): el producto puede llevar varias; la cotización
#                las resta del total solo si el cliente es persona moral (Quote#apply_withholdings)
# No se borra si la usa un producto o es la de por omisión.
class TaxRate < ApplicationRecord
  DEFAULTS = [['IVA 16 %', 16, false], ['IVA 8 % (frontera)', 8, false], ['IVA 0 %', 0, false], ['Exento', 0, true]].freeze
  WITHHOLDING_DEFAULTS = [['Ret. IVA 10.67 %', BigDecimal('10.6667')], ['Ret. ISR 10 %', 10], ['Ret. ISR RESICO 1.25 %', BigDecimal('1.25')],
                          ['Ret. IVA fletes 4 %', 4]].freeze

  enum kind: { transfer: 0, withholding: 1 }

  belongs_to :account
  has_many :catalog_items, dependent: :restrict_with_error

  before_validation :normalize
  validates :name, presence: true, length: { maximum: 60 }
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :default_active
  validate :default_transfer
  after_save :sync_default, if: :is_default?

  scope :ordered, -> { order(percent: :desc, exempt: :asc, name: :asc) }

  def in_use? = catalog_items.exists? || (withholding? && CatalogItem.exists?(['? = ANY(withholding_rate_ids)', id]))

  # Copia que guarda la partida de la cotización.
  def snapshot = { 'id' => id, 'name' => name, 'percent' => percent.to_f }

  # La de por omisión de la cuenta (nil si todavía no tiene lista).
  def self.default_for(account) = account.tax_rates.transfer.find_by(is_default: true)

  # Por nombre («IVA 16 %», «exento») o por porcentaje («16», «16%»), para importar. kind: transfer | withholding
  def self.matching(text, kind: :transfer)
    value = text.to_s.squish.downcase
    return if value.blank?

    scope = where(kind: kind)
    by_name = scope.where('LOWER(name) = ?', value).first
    return by_name if by_name
    return scope.where(exempt: true).first if value.start_with?('exent')

    number = value.delete('% ')[/\A\d+(\.\d+)?\z/]
    scope.where(percent: number.to_d, exempt: false).order(:id).first if number
  end

  # «Ret. IVA 10.67 %; Ret. ISR 10 %» (o con +) → sus ids; lo que no se reconoce se ignora.
  def self.withholding_ids_for(text)
    text.to_s.split(/[;+]/).filter_map { |part| matching(part, kind: :withholding)&.id }.uniq
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.exempt = false if withholding?
    self.percent = 0 if exempt?
  end

  def default_active
    errors.add(:active, 'la de por omisión no se puede desactivar') if is_default? && !active?
  end

  def default_transfer
    errors.add(:is_default, 'solo un impuesto trasladado puede ser el de por omisión') if is_default? && withholding?
  end

  # Solo una por omisión; su porcentaje es el de las partidas sin producto.
  def sync_default
    account.tax_rates.where.not(id: id).where(is_default: true).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
    CaseSetting.for_account(account).update!(default_tax_percent: percent)
  end
end
