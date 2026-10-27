# frozen_string_literal: true

# ================================================================================
# POST /api/v1/accounts/:account_id/tracking_campaigns/:id/pause — botón «Pausar campaña»
# ================================================================================
# Pausa a mano (sin motivo) una campaña Programada o En curso (ver TrackingCampaigns::Pause):
# no entra nadie y cada seguimiento se detiene al llegar su turno; la IA sigue contestando
# a quien ya respondió. Se reanuda con ResumesController.
# 200: { campaign_id:, status: } · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::PausesController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    return render json: { error: 'Solo se pausa una campaña Programada o En curso.' }, status: :unprocessable_entity unless
      ::TrackingCampaigns::Pause.new(campaign).perform

    render json: { campaign_id: campaign.id, status: campaign.reload.status }
  end
end
