# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Ajustes generales del módulo (modo simple / ITIL)
# ================================================================================
# GET   /api/v1/accounts/:account_id/case_setting   → show
# PATCH /api/v1/accounts/:account_id/case_setting   → update (admin)
# ================================================================================

class Api::V1::Accounts::CaseSettingsController < Api::V1::Accounts::BaseController
  before_action :set_setting
  before_action :check_admin_authorization?, only: [:update]

  def show
    render json: setting_json
  end

  def update
    @setting.update!(setting_params)
    render json: setting_json
  end

  private

  def set_setting
    @setting = CaseSetting.for_account(Current.account)
  end

  def setting_params
    params.require(:case_setting).permit(:itil_enabled)
  end

  def setting_json
    { itil_enabled: @setting.itil_enabled }
  end
end
