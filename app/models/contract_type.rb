# == Schema Information
#
# Table name: contract_types
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  color               :string           default("#2781F6"), not null
#  custom_fields       :jsonb            not null
#  default_auto_renew  :boolean          default(TRUE), not null
#  default_every       :integer          default(1), not null
#  default_term_months :integer
#  default_unit        :integer          default("month"), not null
#  name                :string           not null
#  position            :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_contract_types_on_account_id           (account_id)
#  index_contract_types_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# Plan-Contratos R1 — tipo de contrato de la empresa («Monitoreo», «Iguala de soporte»,
# «Licencia»…): sus valores por omisión para el alta y sus campos propios.
class ContractType < ApplicationRecord
  FIELD_TYPES = %w[text number date].freeze

  belongs_to :account
  has_many :contracts, dependent: :restrict_with_error

  enum default_unit: { day: 0, week: 1, month: 2, year: 3 }, _prefix: :default

  before_validation :normalize_custom_fields

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :color, format: { with: /\A#\h{6}\z/ }
  validates :default_every, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
  validates :default_term_months, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 240 },
                                  allow_nil: true
  validate :custom_fields_shape

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  # Cada campo trae su etiqueta; la llave sale de ella (y no cambia si ya existía).
  def normalize_custom_fields
    self.custom_fields = Array(custom_fields).filter_map do |field|
      field = field.to_h.stringify_keys
      label = field['label'].to_s.strip
      next if label.blank?

      key = field['key'].presence || label.parameterize(separator: '_')
      { 'key' => key, 'label' => label, 'type' => FIELD_TYPES.include?(field['type']) ? field['type'] : 'text' }
    end
  end

  def custom_fields_shape
    keys = custom_fields.pluck('key')
    errors.add(:custom_fields, 'tiene campos repetidos') if keys.uniq.size != keys.size
    errors.add(:custom_fields, 'admite hasta 20 campos') if keys.size > 20
  end
end
