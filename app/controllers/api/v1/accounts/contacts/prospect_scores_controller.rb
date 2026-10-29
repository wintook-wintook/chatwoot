# frozen_string_literal: true

# prospeccion P4 (D19) — la puntuación del contacto en su campaña de Prospección más reciente,
# para verla (solo lectura) en su ficha.
#
#   GET /contacts/:contact_id/prospect_score → { score:, parts:, campaign_id:, campaign_name:, scored_at: } o {}
class Api::V1::Accounts::Contacts::ProspectScoresController < Api::V1::Accounts::Contacts::BaseController
  def show
    tracking = @contact.contact_trackings.joins(:tracking_campaign).where(tracking_campaigns: { purpose: 'prospecting' })
                       .where.not(prospect_score: nil).order(created_at: :desc).first
    return render json: {} unless tracking

    render json: { score: tracking.prospect_score, parts: tracking.prospect_score_parts, campaign_id: tracking.tracking_campaign_id,
                   campaign_name: tracking.tracking_campaign.name, scored_at: tracking.prospect_scored_at&.to_i }
  end
end
