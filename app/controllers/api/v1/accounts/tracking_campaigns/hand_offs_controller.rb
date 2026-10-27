# frozen_string_literal: true

# ================================================================================
# prospeccion V6 — POST /api/v1/accounts/:account_id/tracking_campaigns/:id/hand_off
# ================================================================================
# Marca a un prospecto interesado como entregado a un vendedor (etapa handed_off).
# prospeccion P2: lo hace TrackingCampaigns::HandOff (Oportunidades, vendedor, reloj y aviso).
# 200: { tracking_id:, prospect_stage:, handed_off_at:, handoff_due_at: } · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::HandOffsController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    tracking = campaign.contact_trackings.find(params[:tracking_id])
    unless tracking.prospect_stage == 'interested'
      return render json: { error: I18n.t('tracking_campaigns.hand_off.not_interested') }, status: :unprocessable_entity
    end

    TrackingCampaigns::HandOff.new(tracking, user: Current.user).call
    render json: { tracking_id: tracking.id, prospect_stage: tracking.prospect_stage,
                   handed_off_at: tracking.handed_off_at, handoff_due_at: tracking.handoff_due_at }
  end
end
