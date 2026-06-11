# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2I
# ================================================================================
# Controller: Api::V1::Accounts::CaseSlaPoliciesController
#
# GET    /api/v1/accounts/:account_id/case_sla_policies       → index (seed si vacío)
# POST   /api/v1/accounts/:account_id/case_sla_policies       → create
# PATCH  /api/v1/accounts/:account_id/case_sla_policies/:id   → update
# DELETE /api/v1/accounts/:account_id/case_sla_policies/:id   → destroy
# ================================================================================

class Api::V1::Accounts::CaseSlaPoliciesController < Api::V1::Accounts::BaseController
  before_action :set_policy, only: %i[update destroy]

  def index
    CaseSlaPolicy.ensure_defaults_for(Current.account)
    policies = Current.account.case_sla_policies.order(:priority, :case_type_id, :ticket_kind)
    render json: { case_sla_policies: policies.map { |p| policy_json(p) } }
  end

  def create
    policy = Current.account.case_sla_policies.build(policy_params)
    if policy.save
      render json: { case_sla_policy: policy_json(policy) }, status: :created
    else
      render json: { error: policy.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @policy.update(policy_params)
      render json: { case_sla_policy: policy_json(@policy) }
    else
      render json: { error: @policy.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @policy.destroy
    head :no_content
  end

  private

  def set_policy
    @policy = Current.account.case_sla_policies.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Política no encontrada' }, status: :not_found
  end

  def policy_params
    params.require(:case_sla_policy).permit(
      :case_type_id, :ticket_kind, :priority,
      :first_response_time_target, :resolution_time_target,
      :business_hours_only, :active
    )
  end

  def policy_json(policy)
    {
      id:                         policy.id,
      case_type_id:               policy.case_type_id,
      ticket_kind:                policy.ticket_kind,
      priority:                   policy.priority,
      first_response_time_target: policy.first_response_time_target,
      resolution_time_target:     policy.resolution_time_target,
      business_hours_only:        policy.business_hours_only,
      active:                     policy.active
    }
  end
end
