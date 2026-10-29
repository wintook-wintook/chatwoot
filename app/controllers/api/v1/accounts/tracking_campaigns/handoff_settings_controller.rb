# frozen_string_literal: true

# ================================================================================
# prospeccion P2 — PATCH /api/v1/accounts/:account_id/tracking_campaigns/:id/handoff_settings
# ================================================================================
# A qué tablero/columna de Oportunidades entra el interesado, plazo y escalar (horas
# hábiles). Se puede cambiar en cualquier estado de la campaña: vale para las entregas
# que vengan (las ya entregadas conservan su reloj). Sin tablero = entrega solo a mano.
# 200: TrackingCampaign#handoff_settings (ids, horas y nombres del tablero/columna) · 422: { error: }
# ================================================================================
class Api::V1::Accounts::TrackingCampaigns::HandoffSettingsController < Api::V1::Accounts::BaseController
  FIELDS = %i[handoff_board_id handoff_column_id handoff_due_hours handoff_escalate_hours].freeze

  def update
    campaign = Current.account.tracking_campaigns.find(params[:id])
    return render json: { error: campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity unless campaign.update(settings)

    render json: campaign.handoff_settings
  end

  private

  def settings
    FIELDS.index_with { |field| params[field].presence&.to_i }
  end
end
