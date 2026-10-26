# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — POST /api/v1/accounts/:account_id/tracking_campaigns/:id/resume
# ================================================================================
# Reanuda una campaña pausada por un error de configuración de Meta (ver TrackingCampaigns::Resume).
# 200: { campaign_id:, status:, trackings: } · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::ResumesController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    result = ::TrackingCampaigns::Resume.new(campaign).call
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    render json: { campaign_id: campaign.id, status: campaign.status, trackings: result[:trackings] }
  end
end
