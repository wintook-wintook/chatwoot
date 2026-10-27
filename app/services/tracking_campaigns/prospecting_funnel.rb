# frozen_string_literal: true

# ================================================================================
# prospeccion V6 — EL EMBUDO DE UNA CAMPAÑA DE PROSPECCIÓN (§8.1, §10.1)
# ================================================================================
#   Contactados → Respondieron → Interesados → Entregados
#   Salidas: No ahora · No le interesa · No es la persona · Baja · Sin respuesta
#
#   contacted  = ya se le escribió (attempt_count > 0)
#   replied    = tiene etapa (respondió, interesado o entregado) — V5
#   no_reply   = agotó sus toques sin etapa ni salida
# ================================================================================
module TrackingCampaigns::ProspectingFunnel
  EXITS = %w[not_now not_interested wrong_person opted_out].freeze

  module_function

  def for(campaign)
    base = campaign.contact_trackings
    exits = base.where(prospect_exit: EXITS).group(:prospect_exit).count
    {
      total: base.count,
      contacted: base.where('attempt_count > 0').count,
      replied: base.where(prospect_stage: ContactTracking::PROSPECT_STAGES).count,
      interested: base.where(prospect_stage: %w[interested handed_off]).count,
      handed_off: base.where(prospect_stage: 'handed_off').count,
      no_reply: base.where(status: 'completed', prospect_stage: nil, prospect_exit: nil).count
    }.merge(EXITS.to_h { |exit| [exit.to_sym, exits[exit].to_i] })
  end
end
