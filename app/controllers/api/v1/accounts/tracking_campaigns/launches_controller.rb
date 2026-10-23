# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — POST /api/v1/accounts/:account_id/tracking_campaigns/:id/launch
# ================================================================================
# Pone en curso una campaña Guardada (ver TrackingCampaigns::Launch).
# 200: { campaign_id:, status:, queued: } (queued solo por lote) · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::LaunchesController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    result = ::TrackingCampaigns::Launch.new(campaign, current_user).call
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    render json: { campaign_id: campaign.id, status: campaign.status, queued: result[:queued] }.compact
  end
end
