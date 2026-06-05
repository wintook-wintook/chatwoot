# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseRulesController
#
# GET    /api/v1/accounts/:account_id/case_rules       → index
# POST   /api/v1/accounts/:account_id/case_rules       → create
# PATCH  /api/v1/accounts/:account_id/case_rules/:id   → update
# DELETE /api/v1/accounts/:account_id/case_rules/:id   → destroy
# ================================================================================

class Api::V1::Accounts::CaseRulesController < Api::V1::Accounts::BaseController
  before_action :set_rule, only: %i[update destroy]

  # GET /api/v1/accounts/:account_id/case_rules
  def index
    rules = Current.account.case_rules.order(:position)
    render json: { case_rules: rules.map { |r| rule_json(r) } }
  end

  # POST /api/v1/accounts/:account_id/case_rules
  def create
    rule = Current.account.case_rules.build(rule_params)
    if rule.save
      render json: { case_rule: rule_json(rule) }, status: :created
    else
      render json: { error: rule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/accounts/:account_id/case_rules/:id
  def update
    if @rule.update(rule_params)
      render json: { case_rule: rule_json(@rule) }
    else
      render json: { error: @rule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/accounts/:account_id/case_rules/:id
  def destroy
    @rule.destroy
    head :no_content
  end

  private

  def set_rule
    @rule = Current.account.case_rules.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Regla no encontrada' }, status: :not_found
  end

  def rule_params
    params.require(:case_rule).permit(
      :name, :description, :active, :continue_on_match, :position,
      conditions: [:field, :operator, :value],
      actions:    [:type, :value]
    )
  end

  def rule_json(rule)
    {
      id:               rule.id,
      name:             rule.name,
      description:      rule.description,
      active:           rule.active,
      continue_on_match: rule.continue_on_match,
      position:         rule.position,
      conditions:       rule.conditions,
      actions:          rule.actions,
      created_at:       rule.created_at,
      updated_at:       rule.updated_at
    }
  end
end
