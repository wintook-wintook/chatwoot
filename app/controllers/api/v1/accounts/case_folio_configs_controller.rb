# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseFolioConfigsController
#
# GET   /api/v1/accounts/:account_id/case_folio_config   → show (crea default si no existe)
# PATCH /api/v1/accounts/:account_id/case_folio_config   → update
#
# Singular resource (una config por cuenta).
# ================================================================================

class Api::V1::Accounts::CaseFolioConfigsController < Api::V1::Accounts::BaseController
  def show
    render json: { case_folio_config: config_json(config) }
  end

  def update
    if config.update(config_params)
      render json: { case_folio_config: config_json(config) }
    else
      render json: { error: config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def config
    @config ||= CaseFolioConfig.for_account(Current.account)
  end

  def config_params
    params.require(:case_folio_config).permit(:enabled, :template, :per_type, :reset_period)
  end

  def config_json(c)
    {
      enabled:      c.enabled,
      template:     c.template,
      per_type:     c.per_type,
      reset_period: c.reset_period
    }
  end
end
