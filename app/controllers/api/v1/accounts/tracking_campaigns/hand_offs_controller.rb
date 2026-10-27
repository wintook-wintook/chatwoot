# frozen_string_literal: true

# ================================================================================
# prospeccion V6 — POST /api/v1/accounts/:account_id/tracking_campaigns/:id/hand_off
# ================================================================================
# Marca a un prospecto interesado como entregado a un vendedor (etapa handed_off).
# El vendedor lo toma desde su conversación; el plazo y los avisos son P2 (v1.1).
# 200: { tracking_id:, prospect_stage: } · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::HandOffsController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    tracking = campaign.contact_trackings.find(params[:tracking_id])
    unless tracking.prospect_stage == 'interested'
      return render json: { error: I18n.t('tracking_campaigns.hand_off.not_interested') }, status: :unprocessable_entity
    end

    tracking.update!(prospect_stage: 'handed_off')
    render json: { tracking_id: tracking.id, prospect_stage: tracking.prospect_stage }
  end
end
