# frozen_string_literal: true

# ================================================================================
# prospeccion P4 — LA PUNTUACIÓN DEL PROSPECTO, 0 A 100 (§10.11)
# ================================================================================
#   Perfil  (¿se parece a mi cliente ideal?)  reglas de ScoringConfig sobre el contacto;
#           «decide» sin regla → lo que infirió la IA (prospect_decision_maker, D17)
#   Interés (¿qué hizo?)  respondió (etapa V5) · pidió precio/info · pidió cita (o la agendó)
#           · 30 días sin responder (una vez, D18) · dijo «no ahora»
#
# Guarda prospect_score (0–100), el desglose (criterio → puntos, solo los que cuentan) y
# prospect_scored_at. Por ahora SOLO ORDENA: no entrega a nadie (P4.4, después de calibrar).
# Lo llaman el clasificador (V5), la marca de cita y ProspectScoreJob (diario y al configurar).
# ================================================================================
module TrackingCampaigns::ProspectScore
  NO_REPLY_DAYS = 30

  module_function

  def call(tracking, config = nil)
    campaign = tracking.tracking_campaign
    return unless campaign&.prospecting?

    config ||= TrackingCampaigns::ScoringConfig.for(campaign)
    parts = criteria(tracking, config['rules']).index_with { |key| config['weights'][key] }.reject { |_, points| points.zero? }
    tracking.update_columns(prospect_score: parts.values.sum.clamp(0, 100), prospect_score_parts: parts, # rubocop:disable Rails/SkipsModelValidations
                            prospect_scored_at: Time.current)
  end

  # Los criterios que cumple el prospecto.
  def criteria(tracking, rules)
    profile(tracking, rules) + interest(tracking)
  end

  def profile(tracking, rules)
    contact = tracking.contact
    return [] if contact.nil?

    met = %w[industry size].select { |key| TrackingCampaigns::ScoringConfig.matches?(rules[key], contact) }
    decides?(tracking, rules['decider'], contact) ? met + ['decider'] : met
  end

  # D17: con regla manda la regla; sin regla, lo que infirió la IA de sus respuestas.
  def decides?(tracking, rule, contact)
    return TrackingCampaigns::ScoringConfig.matches?(rule, contact) if TrackingCampaigns::ScoringConfig.rule?(rule)

    tracking.prospect_decision_maker == 'yes'
  end

  def interest(tracking)
    signals = Array(tracking.prospect_signals)
    [
      ('replied' if tracking.prospect_stage.present?),
      ('asked_price' if signals.intersect?(%w[price info])),
      ('asked_meeting' if signals.include?('meeting') || tracking.booked_at.present?),
      ('not_now' if tracking.prospect_exit == 'not_now'),
      ('no_reply_30' if no_reply?(tracking))
    ].compact
  end

  def no_reply?(tracking)
    tracking.prospect_stage.nil? && tracking.attempt_count.to_i.positive? &&
      tracking.last_attempt_at.present? && tracking.last_attempt_at <= NO_REPLY_DAYS.days.ago
  end
end
