# frozen_string_literal: true

# Campaña con Vendedor IA — «Redactar con Dali» (TrackingCampaigns::CopyWriter). No guarda: regresa la propuesta y la
# pantalla decide si la usa.
#
#   POST motor2_campaigns/:id/copy  { target: info|opener|touch|email|reminder, number, kind, pending, tone, length,
#                                    instruction, current }
#        → { text } · email: { subject, subject_b, blocks } · 422 { error }
class Api::V1::Accounts::Motor2Campaigns::CopiesController < Api::V1::Accounts::BaseController
  def create
    campaign = Current.account.tracking_campaigns.real.where(engine: '2').find(params[:id])
    result = TrackingCampaigns::CopyWriter.new(campaign,
                                               params.permit(:target, :number, :tone, :length, :instruction, :current, :kind, :pending)).call
    return render(json: { error: result[:error] }, status: :unprocessable_entity) if result[:error]

    render json: result
  end
end
