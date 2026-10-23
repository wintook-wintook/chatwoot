# ================================================================================
# feat/licencias (F2) — EMITIR Y CANCELAR LICENCIAS (Gestionar)
# ================================================================================
# POST …/licenses/account_licenses
#   { target_account_id, license_plan_id, start: now|queue, max_agents?, duration_days?, name?, notes? }
#   → Licenses::Issuer: «now» reemplaza la activa; «queue» la deja en cola tras la vigente.
# POST …/licenses/account_licenses/:id/cancel → solo una PROGRAMADA (la vigente no se cancela
#   desde aquí: para cambiarla se emite otra con «now»).
# ================================================================================
class Api::V1::Accounts::Licenses::AccountLicensesController < Api::V1::Accounts::Licenses::BaseController
  before_action :check_manage_permission

  def create
    licencia = Licenses::Issuer.new(
      account: Account.find(params.require(:target_account_id)), plan: LicensePlan.find(params.require(:license_plan_id)),
      created_by: Current.user, start: params[:start], max_agents: params[:max_agents],
      duration_days: params[:duration_days], name: params[:name], notes: params[:notes]
    ).perform
    render json: licencia.slice(:id, :account_id, :name, :status, :max_agents, :duration_days, :starts_at, :expires_at), status: :created
  rescue Licenses::Issuer::Invalid => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def cancel
    licencia = AccountLicense.find(params[:id])
    return render json: { message: I18n.t('licenses.errors.only_scheduled') }, status: :unprocessable_entity unless licencia.scheduled?

    licencia.update!(status: :cancelled)
    render json: { id: licencia.id, status: licencia.status }
  end
end
