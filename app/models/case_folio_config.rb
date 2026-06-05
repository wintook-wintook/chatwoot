# frozen_string_literal: true

# == Schema Information
#
# Table name: case_folio_configs
#
#  id           :bigint           not null, primary key
#  enabled      :boolean          default(TRUE), not null
#  per_type     :boolean          default(TRUE), not null
#  reset_period :string           default("never"), not null
#  template     :string           default("{PREFIX}-{SEQ:5}"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_case_folio_configs_on_account_id  (account_id) UNIQUE
#
# ================================================================================
# @tickets_cases
# ================================================================================
# Modelo: CaseFolioConfig
# Descripción: Configuración del folio de tickets POR CUENTA.
#   - template:     plantilla con tokens, ej. "{PREFIX}-{YYYY}-{SEQ:5}"
#   - per_type:     true → un consecutivo por cada tipo; false → uno general
#   - reset_period: never | daily | monthly | yearly (cuándo reinicia el consecutivo)
# ================================================================================

class CaseFolioConfig < ApplicationRecord
  belongs_to :account

  RESET_PERIODS = %w[never daily monthly yearly].freeze

  validates :template, presence: true
  validates :reset_period, inclusion: { in: RESET_PERIODS }

  # Devuelve (o crea con defaults) la config de una cuenta.
  def self.for_account(account)
    account.case_folio_config || account.create_case_folio_config!
  end
end
