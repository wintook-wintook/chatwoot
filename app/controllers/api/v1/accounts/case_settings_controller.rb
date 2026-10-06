# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Ajustes generales del módulo (ventana de reapertura)
# ================================================================================
# GET   /api/v1/accounts/:account_id/case_setting   → show
# PATCH /api/v1/accounts/:account_id/case_setting   → update (admin)
#
# El modo ITIL/simple pasó a ser por tipo de caso (ver CaseType#itil_enabled /
# Api::V1::Accounts::CaseTypesController) — ya no vive aquí.
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
    permitted = params.require(:case_setting).permit(:reopen_window_days, :reopen_on_customer_reply)
    # La ventana no puede ser negativa; 0 = sin límite.
    permitted[:reopen_window_days] = [permitted[:reopen_window_days].to_i, 0].max if permitted.key?(:reopen_window_days)
    permitted
  end

  def setting_json
    {
      reopen_window_days: @setting.reopen_window_days,
      reopen_on_customer_reply: @setting.reopen_on_customer_reply
    }
  end
end
