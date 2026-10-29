# frozen_string_literal: true

# ================================================================================
# EL EMBUDO DE UNA CAMPAÑA — uno solo, para todas las campañas y canales (§10.12 U2)
# ================================================================================
# Junta «Intenciones» (palabras clave del agente) y el «Embudo de prospección» (la IA, V5):
#
#   contactados   = ya se le escribió                      attempt_count > 0
#   respondieron  = la IA clasificó o procesó una respuesta prospect_stage o last_intent
#   interesados   = la IA lo vio interesado O una palabra  prospect_stage interesado/entregado
#                   clave lo marcó (cada uno cuenta 1 vez)  o interested_at
#   con cita      = agendó (palabra clave / calendario)     booked_at
#   entregados    = se entregó a un vendedor (P2)           prospect_stage = handed_off
#   objetivo      = el agente lo cumplió (o el vendedor lo atendió, P2b)   status objective_met
#   salidas       = no ahora · no le interesa · no es la persona · baja · rebotó   prospect_exit
#   sin respuesta = agotó sus toques sin responder nada
#   pausados / cancelados por regla = los dejó así una palabra clave (van a «⚙️ Control»)
#
# Garantía (D27): las palabras clave no se tocan y ningún número baja respecto a «Intenciones».
# ================================================================================
module TrackingCampaigns::CampaignFunnel
  EXITS = %w[not_now not_interested wrong_person opted_out bounced].freeze
  KEYS = (%i[total contacted replied interested appointment handed_off objective_met no_reply paused_rule cancelled_rule] +
          EXITS.map(&:to_sym)).freeze
  EMPTY = KEYS.index_with(0).freeze

  module_function

  def for(campaign)
    by_campaign([campaign.id])[campaign.id]
  end

  # { campaign_id => { contacted: N, ... } } con una consulta agrupada por número.
  def by_campaign(ids)
    return {} if ids.blank?

    base = ContactTracking.where(tracking_campaign_id: ids)
    counts = scopes(base).transform_values { |relation| relation.group(:tracking_campaign_id).count }
    exits = base.where(prospect_exit: EXITS).group(:tracking_campaign_id, :prospect_exit).count

    ids.index_with do |id|
      EMPTY.merge(counts.transform_values { |by_campaign| by_campaign[id].to_i })
           .merge(EXITS.to_h { |exit| [exit.to_sym, exits[[id, exit]].to_i] })
    end
  end

  def scopes(base)
    by_rule = ->(status, action) { base.where(status: status).where("keyword_action_fired->>'action' = ?", action) }
    {
      total: base,
      contacted: base.where('attempt_count > 0'),
      replied: base.where('prospect_stage IS NOT NULL OR last_intent IS NOT NULL'),
      interested: base.where("prospect_stage IN ('interested', 'handed_off') OR interested_at IS NOT NULL"),
      appointment: base.where.not(booked_at: nil),
      handed_off: base.where(prospect_stage: 'handed_off'),
      objective_met: base.where(status: 'objective_met'),
      no_reply: base.where(status: 'completed', prospect_stage: nil, prospect_exit: nil, last_intent: nil),
      paused_rule: by_rule.call('paused', 'pause'),
      cancelled_rule: by_rule.call('cancelled', 'cancel')
    }
  end
end
