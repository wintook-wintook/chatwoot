# == Schema Information
#
# Table name: license_plans
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  default_max_agents :integer          not null
#  duration_days      :integer          not null
#  features           :jsonb            not null
#  license_type       :integer          default("paid"), not null
#  name               :string           not null
#  position           :integer          default(0), not null
#  signup_default     :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_license_plans_one_signup_default  (signup_default) UNIQUE WHERE signup_default
#
# ================================================================================
# feat/licencias (F0) — CATÁLOGO DE PLANES DE LICENCIA
# ================================================================================
# Un plan es el MOLDE de una licencia: nombre, duración, agentes por omisión y qué canales y
# funciones incluye (`features`, nombres de config/features.yml). Al emitir una licencia
# (AccountLicense) se copian sus valores: editar o desactivar el plan después no cambia lo que
# ya se emitió.
#
# El plan con `signup_default` es la demo que recibe toda cuenta nueva (F1). Solo uno a la vez
# (índice único parcial); marcar otro desmarca el anterior.
# Plan: docs/licencias_plan_v1.md §4 y §7
# ================================================================================
class LicensePlan < ApplicationRecord
  enum license_type: { demo: 0, paid: 1 }

  has_many :account_licenses, dependent: :nullify

  validates :name, presence: true, length: { maximum: 120 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :default_max_agents, numericality: { only_integer: true, greater_than: 0 }
  validate :features_must_be_a_list

  before_save :release_previous_signup_default, if: -> { signup_default? && will_save_change_to_signup_default? }

  scope :available, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def self.signup_default_plan
    available.find_by(signup_default: true)
  end

  private

  def features_must_be_a_list
    errors.add(:features, :invalid) unless features.is_a?(Array) && features.all?(String)
  end

  # El índice único no deja dos planes de registro: se desmarca el anterior en la misma transacción.
  def release_previous_signup_default
    self.class.where(signup_default: true).where.not(id: id).update_all(signup_default: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
