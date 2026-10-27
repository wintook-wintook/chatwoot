# frozen_string_literal: true

# ================================================================================
# prospeccion P3 — POST /api/v1/accounts/:account_id/tracking_campaigns/:id/subject_winner
# ================================================================================
# Quedarse con el asunto A o B: desde ahí todos los nuevos reciben ese asunto y la
# comparación queda como estaba. 200: TrackingCampaigns::SubjectTest.stats · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::SubjectWinnersController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.find(params[:id])
    unless TrackingCampaigns::SubjectTest.choose!(campaign, params[:variant])
      return render json: { error: I18n.t('tracking_campaigns.subject_test.invalid') }, status: :unprocessable_entity
    end

    render json: TrackingCampaigns::SubjectTest.stats(campaign)
  end
end
