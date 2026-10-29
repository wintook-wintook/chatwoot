# frozen_string_literal: true

# ================================================================================
# prospeccion P4 — LOS PESOS Y LAS REGLAS DE LA PUNTUACIÓN (§10.11, D16)
# ================================================================================
# Por campaña (tracking_campaigns.scoring); lo que no esté guardado toma el valor sugerido
# de §8.2. Las reglas dicen qué significa cada criterio del Perfil para ESTE cliente ideal:
#
#   industry / size / decider → { labels: [...], attribute_key: 'ciudad', attribute_values: [...] }
#   cumple si el contacto tiene alguna de esas etiquetas O su atributo vale alguno de esos valores
#   (sin distinguir mayúsculas). Sin regla, el criterio vale 0 (decider: lo infiere la IA, D17).
# ================================================================================
module TrackingCampaigns::ScoringConfig
  DEFAULT_WEIGHTS = {
    'industry' => 20, 'size' => 15, 'decider' => 15, # Perfil (máx. 50)
    'replied' => 10, 'asked_price' => 20, 'asked_meeting' => 20, # Interés (máx. 50)
    'no_reply_30' => -10, 'not_now' => -15
  }.freeze
  PROFILE = %w[industry size decider].freeze
  WEIGHT_RANGE = (-50..50)
  EMPTY_RULE = { 'labels' => [], 'attribute_key' => '', 'attribute_values' => [] }.freeze

  module_function

  def for(campaign)
    saved = campaign.scoring.to_h
    weights = DEFAULT_WEIGHTS.merge(saved.fetch('weights', {}).slice(*DEFAULT_WEIGHTS.keys).transform_values(&:to_i))
    rules = PROFILE.index_with { |key| EMPTY_RULE.merge(saved.dig('rules', key).to_h.slice(*EMPTY_RULE.keys)) }
    { 'weights' => weights, 'rules' => rules }
  end

  # Lo que manda la pantalla, limpio: pesos enteros dentro del rango y reglas sin vacíos.
  def sanitize(params)
    params = params.to_h.deep_stringify_keys
    weights = params.fetch('weights', {}).slice(*DEFAULT_WEIGHTS.keys)
                    .transform_values { |value| value.to_i.clamp(WEIGHT_RANGE.min, WEIGHT_RANGE.max) }
    rules = PROFILE.index_with { |key| clean_rule(params.dig('rules', key).to_h) }
    { 'weights' => weights, 'rules' => rules }
  end

  def clean_rule(rule)
    { 'labels' => Array(rule['labels']).map { |label| label.to_s.strip.downcase }.compact_blank.uniq,
      'attribute_key' => rule['attribute_key'].to_s.strip,
      'attribute_values' => Array(rule['attribute_values']).map { |value| value.to_s.strip }.compact_blank.uniq }
  end

  def rule?(rule)
    rule['labels'].any? || (rule['attribute_key'].present? && rule['attribute_values'].any?)
  end

  def matches?(rule, contact)
    return false unless rule?(rule)
    return true if contact.label_list.map(&:downcase).intersect?(rule['labels'])

    value = contact.custom_attributes.to_h[rule['attribute_key']] || contact.additional_attributes.to_h[rule['attribute_key']]
    value.present? && rule['attribute_values'].map(&:downcase).include?(value.to_s.strip.downcase)
  end
end
