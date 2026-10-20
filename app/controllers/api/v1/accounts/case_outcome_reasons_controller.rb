# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Clase-Comercial F3
# ================================================================================
# Controller: Api::V1::Accounts::CaseOutcomeReasonsController
# Catálogo de motivos de una oportunidad: ganada, perdida, cancelada y pospuesta.
#
# GET    /api/v1/accounts/:account_id/case_outcome_reasons        → index (?outcome=won|lost|cancelled|postponed)
# POST   /api/v1/accounts/:account_id/case_outcome_reasons        → create (admin)
# PATCH  /api/v1/accounts/:account_id/case_outcome_reasons/:id    → update (admin)
# DELETE /api/v1/accounts/:account_id/case_outcome_reasons/:id    → destroy (admin)
#
# Borrar un motivo deja a sus oportunidades sin motivo (FK on_delete: nullify); para
# conservar la historia conviene desactivarlo (`active: false`).
# ================================================================================

class Api::V1::Accounts::CaseOutcomeReasonsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:index]
  before_action :set_reason, only: %i[update destroy]

  def index
    reasons = CaseOutcomeReason.ensure_defaults_for(Current.account)
    reasons = reasons.where(outcome: params[:outcome]) if CaseOutcomeReason.outcomes.key?(params[:outcome].to_s)
    render json: { case_outcome_reasons: reasons.map { |r| reason_json(r) } }
  end

  def create
    reason = Current.account.case_outcome_reasons.build(reason_params)
    reason.position ||= Current.account.case_outcome_reasons.where(outcome: reason.outcome).count
    if reason.save
      render json: { case_outcome_reason: reason_json(reason) }, status: :created
    else
      render json: { error: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @reason.update(reason_params)
      render json: { case_outcome_reason: reason_json(@reason) }
    else
      render json: { error: @reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @reason.destroy
    head :no_content
  end

  private

  def set_reason
    @reason = Current.account.case_outcome_reasons.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Motivo no encontrado' }, status: :not_found
  end

  def reason_params
    params.require(:case_outcome_reason).permit(:outcome, :label, :position, :active)
  end

  def reason_json(reason)
    {
      id:       reason.id,
      outcome:  reason.outcome,
      label:    reason.label,
      position: reason.position,
      active:   reason.active
    }
  end
end
