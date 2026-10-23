# ================================================================================
# feat/licencias (F2) — CATÁLOGO DE PLANES
# ================================================================================
# GET   …/licenses/plans        → { plans, available_features }
# POST  …/licenses/plans        (Gestionar)
# PATCH …/licenses/plans/:id    (Gestionar)
# No se borran: se desactivan (active: false). Las licencias ya emitidas guardan su copia.
# ================================================================================
class Api::V1::Accounts::Licenses::PlansController < Api::V1::Accounts::Licenses::BaseController
  before_action :check_manage_permission, only: [:create, :update]

  def index
    render json: { plans: LicensePlan.ordered.map { |plan| plan_json(plan) }, available_features: LicensePlan.feature_names }
  end

  def create
    plan = LicensePlan.create!(plan_params)
    render json: plan_json(plan), status: :created
  end

  def update
    plan = LicensePlan.find(params[:id])
    plan.update!(plan_params)
    render json: plan_json(plan)
  end

  private

  def plan_params
    params.require(:plan).permit(:name, :duration_days, :default_max_agents, :license_type, :signup_default, :active, :position, features: [])
  end

  def plan_json(plan)
    plan.slice(:id, :name, :duration_days, :default_max_agents, :license_type, :features, :signup_default, :active, :position)
        .merge(accounts_count: plan.account_licenses.active.count)
  end
end
