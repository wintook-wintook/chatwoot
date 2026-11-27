# CrmZeus Q3.1 — parámetros de CrmZeus de la cuenta.
#
#   GET   /crm/settings   (quien tiene Ventas)
#   PATCH /crm/settings { settings: { require_delivery_date, show_article_notes, show_kit_components } }   (solo Administrador)
class Api::V1::Accounts::Crm::SettingsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin_access, only: :update

  def show
    render json: { settings: setting.as_crm_json }
  end

  def update
    return render_errors(setting) unless setting.update(settings_params)

    render json: { settings: setting.as_crm_json }
  end

  private

  def setting
    @setting ||= CrmSetting.for_account(Current.account)
  end

  def settings_params
    params.require(:settings).permit(:require_delivery_date, :show_article_notes, :show_kit_components)
  end
end
