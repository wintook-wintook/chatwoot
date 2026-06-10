# frozen_string_literal: true

# == Schema Information
#
# Table name: case_ai_configs
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(FALSE), not null
#  model_override :string
#  modes          :jsonb            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_case_ai_configs_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# @tickets_cases 3A
# Configuración de IA del Gestor de Tickets por cuenta. `modes` guarda, por cada
# acción de IA, su modo de operación: 'off' (no corre), 'suggest' (propone y el
# agente aprueba) o 'auto' (aplica directo). Diseño "mixto configurable".
class CaseAiConfig < ApplicationRecord
  belongs_to :account

  # Acciones de IA disponibles (se irán implementando por bloque de la Fase 3).
  ACTIONS = %w[classify reply summarize duplicate follow_up].freeze
  MODES   = %w[off suggest auto].freeze
  DEFAULT_MODE = 'suggest'

  validate :validate_modes

  # Config de la cuenta (la crea con defaults si no existe).
  def self.for_account(account)
    account.case_ai_config || account.create_case_ai_config!(enabled: false, modes: default_modes)
  end

  def self.default_modes
    ACTIONS.index_with { DEFAULT_MODE }
  end

  # Modo efectivo de una acción: 'off' si la IA está deshabilitada globalmente.
  def mode_for(action)
    return 'off' unless enabled

    m = modes[action.to_s]
    MODES.include?(m) ? m : DEFAULT_MODE
  end

  def active?(action)
    mode_for(action) != 'off'
  end

  private

  def validate_modes
    return if modes.blank?

    modes.each do |action, mode|
      errors.add(:modes, "acción inválida: #{action}") unless ACTIONS.include?(action.to_s)
      errors.add(:modes, "modo inválido: #{mode}") unless MODES.include?(mode.to_s)
    end
  end
end
