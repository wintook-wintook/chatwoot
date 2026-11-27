# frozen_string_literal: true

# POST /api/v1/accounts/:account_id/tracking_campaigns/:id/finish — botón «Terminar campaña» (TrackingCampaigns::Finish):
# pasa a Terminada, cancela lo que faltaba por salir y conserva sus Resultados.
# 200: { campaign_id:, status:, cancelled: } · 422: { error: }
class Api::V1::Accounts::TrackingCampaigns::FinishesController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    cancelled = ::TrackingCampaigns::Finish.new(campaign).perform
    return render json: { error: 'La campaña ya está terminada.' }, status: :unprocessable_entity if cancelled.nil?

    render json: { campaign_id: campaign.id, status: campaign.reload.status, cancelled: cancelled }
  end
end
