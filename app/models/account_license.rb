# == Schema Information
#
# Table name: account_licenses
#
#  id              :bigint           not null, primary key
#  duration_days   :integer          not null
#  expires_at      :datetime
#  license_type    :integer          default("paid"), not null
#  max_agents      :integer          not null
#  metadata        :jsonb            not null
#  name            :string           not null
#  notes           :text
#  reminded_at     :jsonb            not null
#  starts_at       :datetime
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  created_by_id   :bigint
#  license_plan_id :bigint
#
# Indexes
#
#  index_account_licenses_on_account_id_and_status  (account_id,status)
#  index_account_licenses_on_created_by_id          (created_by_id)
#  index_account_licenses_on_license_plan_id        (license_plan_id)
#  index_account_licenses_on_status_and_expires_at  (status,expires_at)
#  index_account_licenses_one_active_per_account    (account_id) UNIQUE WHERE (status = 0)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (license_plan_id => license_plans.id) ON DELETE => nullify
#
# ================================================================================
# feat/licencias (F0) — LICENCIA DE UNA CUENTA
# ================================================================================
# El historial de licencias de una cuenta. Lo que vale es la ACTIVA (a lo sumo una, por índice
# único parcial); las PROGRAMADAS esperan en cola a que termine la vigente (F3).
#
#   active     la que manda hoy: su max_agents es el tope de agentes
#   scheduled  pagada por adelantado, arranca sola al vencer la activa
#   expired    terminó sin cola: la cuenta queda suspendida (F3)
#   cancelled  reemplazada por otra o cancelada a mano
#
# name / max_agents / duration_days son la COPIA del plan al emitir (snapshot), ajustable para
# esa cuenta. Una cuenta sin filas está FUERA DE LICENCIA: se comporta como hoy.
# Plan: docs/licencias_plan_v1.md §4 y §5
# ================================================================================
class AccountLicense < ApplicationRecord
  enum license_type: { demo: 0, paid: 1 }
  enum status: { active: 0, scheduled: 1, expired: 2, cancelled: 3 }

  belongs_to :account
  belongs_to :license_plan, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :name, presence: true, length: { maximum: 120 }
  validates :max_agents, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :status, uniqueness: { scope: :account_id }, if: :active?
  validate :expires_after_start

  private

  def expires_after_start
    return if starts_at.blank? || expires_at.blank? || expires_at > starts_at

    errors.add(:expires_at, :invalid)
  end
end
