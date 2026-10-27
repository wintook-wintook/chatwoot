# frozen_string_literal: true

# ================================================================================
# prospeccion P4 — PATCH /api/v1/accounts/:account_id/tracking_campaigns/:id/scoring
# ================================================================================
# Los pesos y las reglas de la puntuación de una campaña de Prospección (D16), en cualquier
# estado. { scoring: { weights:, rules: } } o { copy_from_campaign_id: } (copiar de otra) o
# { reset: true } (volver a los sugeridos). Recalcula a sus prospectos en segundo plano.
# 200: TrackingCampaigns::ScoringConfig.for · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::ScoringsController < Api::V1::Accounts::BaseController
  def update
    campaign = Current.account.tracking_campaigns.find(params[:id])
    return render json: { error: I18n.t('tracking_campaigns.scoring.not_prospecting') }, status: :unprocessable_entity unless campaign.prospecting?

    campaign.update!(scoring: new_scoring)
    TrackingCampaigns::ProspectScoreJob.perform_later(campaign.id)
    render json: TrackingCampaigns::ScoringConfig.for(campaign)
  end

  private

  def new_scoring
    return {} if ActiveModel::Type::Boolean.new.cast(params[:reset])
    return Current.account.tracking_campaigns.find(params[:copy_from_campaign_id]).scoring if params[:copy_from_campaign_id].present?

    TrackingCampaigns::ScoringConfig.sanitize(params.require(:scoring).permit!)
  end
end
