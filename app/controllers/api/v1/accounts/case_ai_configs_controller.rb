# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3A
# ================================================================================
# Controller: Api::V1::Accounts::CaseAiConfigsController
#
# GET   /api/v1/accounts/:account_id/case_ai_config   → show (crea default si no existe)
# PATCH /api/v1/accounts/:account_id/case_ai_config   → update
#
# Singular resource (una config de IA por cuenta).
# ================================================================================

class Api::V1::Accounts::CaseAiConfigsController < Api::V1::Accounts::BaseController
  def show
    render json: { case_ai_config: config_json(config) }
  end

  def update
    if config.update(update_attrs)
      render json: { case_ai_config: config_json(config) }
    else
      render json: { error: config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def config
    @config ||= CaseAiConfig.for_account(Current.account)
  end

  def update_attrs
    permitted = params.require(:case_ai_config).permit(
      :enabled, :model_override, modes: CaseAiConfig::ACTIONS
    )
    # merge para no perder modos no enviados
    permitted[:modes] = config.modes.merge(permitted[:modes].to_h) if permitted.key?(:modes)
    permitted
  end

  def config_json(c)
    {
      enabled:        c.enabled,
      modes:          c.modes,
      model_override: c.model_override,
      available:      Cases::Ai::BaseService.new(account: Current.account).available?,
      actions:        CaseAiConfig::ACTIONS,
      mode_options:   CaseAiConfig::MODES
    }
  end
end
