# == Schema Information
#
# Table name: crm_payment_terms
#
#  id                             :bigint           not null, primary key
#  active                         :boolean          default(TRUE), not null
#  early_payment_days             :integer          default(0), not null
#  early_payment_discount_percent :decimal(5, 2)    default(0.0), not null
#  is_default                     :boolean          default(FALSE), not null
#  name                           :string(100)      not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#
# Indexes
#
#  index_crm_payment_terms_on_account_id  (account_id)
#  index_crm_payment_terms_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus O0 — condición de pago (CONDICIONES_PAGO de Microsip) con sus plazos
# (PLAZOS_COND_PAG): «3 pagos» = 30 % hoy, 35 % a 15 días, 35 % a 30 días.
class CrmPaymentTerm < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  has_many :installments, -> { order(:position, :days) }, class_name: 'CrmPaymentTermInstallment',
                                                          foreign_key: :payment_term_id, inverse_of: :payment_term,
                                                          dependent: :destroy
  accepts_nested_attributes_for :installments, allow_destroy: true

  validates :name, length: { maximum: 100 }
  validates :early_payment_discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :early_payment_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :installments_add_up

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  # Días del último plazo (lo que se suele mostrar como «crédito a N días»).
  def credit_days
    installments.map(&:days).max || 0
  end

  private

  # Sin plazos = contado. Con plazos, los porcentajes deben sumar 100.
  def installments_add_up
    live = installments.reject(&:marked_for_destruction?)
    return if live.empty?
    return if live.sum { |i| i.percent.to_d } == 100

    errors.add(:installments, 'los porcentajes de los plazos deben sumar 100')
  end
end
