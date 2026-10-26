# frozen_string_literal: true

# == Schema Information
#
# Table name: case_settings
#
#  id                         :bigint           not null, primary key
#  business_summary_user_ids  :bigint           default([]), not null, is an Array
#  default_currency           :string(3)        default("MXN"), not null
#  default_tax_percent        :decimal(5, 2)    default(0.0), not null
#  itil_enabled               :boolean          default(FALSE), not null
#  quotes_require_opportunity :boolean          default(FALSE), not null
#  reopen_on_customer_reply   :boolean          default(TRUE), not null
#  reopen_window_days         :integer          default(30), not null
#  task_priority_weights      :jsonb            not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#
# Indexes
#
#  index_case_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# @tickets_cases — Ajustes generales del módulo de tickets por cuenta (ventana de
# reapertura). El modo ITIL/simple dejó de ser un ajuste de cuenta y ahora es por
# tipo de caso — ver CaseType#itil_enabled. La columna `itil_enabled` de esta
# tabla sigue en la base (se elimina en un segundo PR) pero ya no se lee ni escribe.
class CaseSetting < ApplicationRecord
  belongs_to :account

  # Plan-Clase-Comercial F3 — moneda con la que nace una oportunidad.
  validates :default_currency, format: { with: /\A[A-Z]{3}\z/ }
  # Plan-Bandeja-Prioridad F3 — pesos del puntaje de «Mi día» (solo los que la
  # cuenta cambió; ver Cases::TaskPriorityScore::DEFAULT_WEIGHTS).
  WEIGHT_RANGE = (-100..200)
  URGENT_SCORE_RANGE = (1..500)
  before_validation :normalize_task_priority_weights
  validate :task_priority_weights_in_range
  # «Resumen del negocio» — agentes autorizados (los administradores siempre lo ven).
  before_validation :normalize_business_summary_user_ids

  def self.for_account(account)
    account.case_setting || account.create_case_setting!
  end

  # Los pesos vigentes: los de la cuenta encima de los de fábrica.
  def task_priority_weights_effective
    defaults = Cases::TaskPriorityScore::DEFAULT_WEIGHTS
    defaults.merge(task_priority_weights.to_h.symbolize_keys.slice(*defaults.keys))
  end

  # ¿Puede ver el «Resumen del negocio»? Administradores siempre; los demás, solo
  # si el administrador los marcó.
  def business_summary_visible_to?(user)
    return false unless user

    account_user = account.account_users.find_by(user_id: user.id)
    return false unless account_user
    return true if account_user.administrator?
    # Plan-Roles-Permisos — los roles que ven todos los Informes (Supervisor, Consulta).
    return true if %w[all view].include?(account_user.access_grant.level(:reports))

    business_summary_user_ids.include?(user.id)
  end

  private

  # Solo usuarios de esta cuenta, sin repetir.
  def normalize_business_summary_user_ids
    ids = Array(business_summary_user_ids).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
    self.business_summary_user_ids = account ? account.account_users.where(user_id: ids).pluck(:user_id).sort : ids
  end

  # Solo llaves conocidas, como enteros; lo igual al de fábrica no se guarda.
  def normalize_task_priority_weights
    defaults = Cases::TaskPriorityScore::DEFAULT_WEIGHTS
    raw = task_priority_weights.to_h.symbolize_keys.slice(*defaults.keys)
    self.task_priority_weights = raw.each_with_object({}) do |(key, value), out|
      int = Integer(value.to_s, exception: false)
      out[key.to_s] = int.nil? ? value : int unless int == defaults[key]
    end
  end

  def task_priority_weights_in_range
    task_priority_weights.each do |key, value|
      range = key == 'urgent_score' ? URGENT_SCORE_RANGE : WEIGHT_RANGE
      next if value.is_a?(Integer) && range.cover?(value)

      errors.add(:task_priority_weights, "#{key}: debe ser un entero entre #{range.min} y #{range.max}")
    end
  end
end
