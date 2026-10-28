# frozen_string_literal: true

# ================================================================================
# prospeccion P3 — PRUEBA A/B DE ASUNTOS (§10.10)
# ================================================================================
# En campañas por correo con asunto B (§10.12: cualquier campaña). El asunto se elige al ABRIR la
# conversación (TrackingBuilder#open_conversation, con el primer toque):
#
#   sin asunto B             → A, sin anotar variante
#   con B y sin ganador      → el que lleve menos (A, B, A, B…) y se anota en el seguimiento
#   con ganador              → el ganador, sin anotar (la comparación queda como estaba)
#
# Quien ya tenía hilo conserva su asunto: no participa.
# Comparación: contactados y respondieron (etapa de V5) por asunto. Hasta MIN_SAMPLE
# contactados en cada uno no se señala a ninguno.
# ================================================================================
module TrackingCampaigns::SubjectTest
  VARIANTS = %w[a b].freeze
  MIN_SAMPLE = 20

  module_function

  def running?(campaign)
    campaign.email_subject.present? && campaign.email_subject_b.present? && campaign.subject_ab_winner.blank?
  end

  # [plantilla del asunto, variante a anotar o nil]
  def pick(campaign)
    return [subject(campaign, campaign.subject_ab_winner), nil] if campaign.subject_ab_winner.present?
    return [campaign.email_subject, nil] unless running?(campaign)

    counts = campaign.contact_trackings.where(subject_variant: VARIANTS).group(:subject_variant).count
    variant = counts['a'].to_i <= counts['b'].to_i ? 'a' : 'b'
    [subject(campaign, variant), variant]
  end

  def subject(campaign, variant)
    variant == 'b' ? campaign.email_subject_b : campaign.email_subject
  end

  def choose!(campaign, variant)
    return false unless VARIANTS.include?(variant.to_s) && campaign.email_subject_b.present?

    campaign.update!(subject_ab_winner: variant.to_s)
  end

  # nil si la campaña nunca tuvo prueba.
  def stats(campaign)
    return nil if campaign.email_subject_b.blank?

    rows = VARIANTS.index_with { |variant| variant_stats(campaign, variant) }
    { variants: rows, winner: campaign.subject_ab_winner, leader: leader(rows), min_sample: MIN_SAMPLE }
  end

  def variant_stats(campaign, variant)
    base = campaign.contact_trackings.where(subject_variant: variant)
    contacted = base.where('attempt_count > 0').count
    replied = base.where.not(prospect_stage: nil).count
    { subject: subject(campaign, variant), contacted: contacted, replied: replied,
      rate: contacted.positive? ? (replied * 100.0 / contacted).round(1) : 0.0 }
  end

  # La que va ganando, solo con muestra suficiente en las dos y si no empatan.
  def leader(rows)
    return nil if rows.values.any? { |row| row[:contacted] < MIN_SAMPLE }

    a, b = rows.values_at('a', 'b').pluck(:rate)
    return nil if a == b

    a > b ? 'a' : 'b'
  end
end
