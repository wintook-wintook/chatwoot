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
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_setting
    @setting = CaseSetting.for_account(Current.account)
  end

  def setting_params
    permitted = params.require(:case_setting).permit(:reopen_window_days, :reopen_on_customer_reply, :default_currency,
                                                     task_priority_weights: Cases::TaskPriorityScore::DEFAULT_WEIGHTS.keys,
                                                     business_summary_user_ids: [])
    # La ventana no puede ser negativa; 0 = sin límite.
    permitted[:reopen_window_days] = [permitted[:reopen_window_days].to_i, 0].max if permitted.key?(:reopen_window_days)
    # Plan-Clase-Comercial F3 — código ISO de 3 letras (MXN, USD…).
    permitted[:default_currency] = permitted[:default_currency].to_s.strip.upcase if permitted.key?(:default_currency)
    permitted
  end

  def setting_json
    {
      reopen_window_days: @setting.reopen_window_days,
      reopen_on_customer_reply: @setting.reopen_on_customer_reply,
      default_currency: @setting.default_currency,
      # Plan-Bandeja-Prioridad F3 — vigentes y de fábrica (para «Restaurar»).
      task_priority_weights: @setting.task_priority_weights_effective,
      task_priority_defaults: Cases::TaskPriorityScore::DEFAULT_WEIGHTS,
      # «Resumen del negocio»: quién más puede verlo y si el usuario actual puede.
      business_summary_user_ids: @setting.business_summary_user_ids,
      can_view_business_summary: @setting.business_summary_visible_to?(current_user)
    }
  end
end
