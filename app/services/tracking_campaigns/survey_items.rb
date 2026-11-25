# frozen_string_literal: true

# Campaña con IA · Encuesta — las preguntas con su tipo y qué cuenta como «baja», y a quién le llega el caso.
#
#   brief['survey_items'] = [{ 'text' => '¿Nos recomendarías?', 'type' => 'scale10', 'low' => 7 }]   (hasta 5)
#       type: scale10 (0–10) · scale5 (1–5) · yesno · open;  low: menor a esto es baja (de fábrica 7 y 3)
#   brief['low_case']     = { 'user_id', 'team_id', 'case_type_id', 'priority' }   el caso por calificación baja
#
# brief['survey_questions'] se arma de aquí con el rango en el texto («(del 0 al 10)»): así la IA, el correo con botones
# (TrackingCampaigns::SurveyLink) y la página pública saben cómo se contesta cada una.
module TrackingCampaigns::SurveyItems
  TYPES = %w[scale10 scale5 yesno open].freeze
  MAX = 5
  DEFAULT_LOW = { 'scale10' => 7, 'scale5' => 3 }.freeze
  HINTS = { 'scale10' => '(del 0 al 10)', 'scale5' => '(del 1 al 5)', 'yesno' => '(sí o no)' }.freeze
  RANGE = /\b(?:del\s*)?[01]\s*(?:al|a|-)\s*(?:10|5)\b|s[ií]\s*o\s*no/i
  PRIORITIES = %w[low medium high urgent].freeze

  module_function

  def sanitize(raw)
    Array(raw).first(MAX).filter_map do |row|
      row = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
      text = row['text'].to_s.squish.first(300)
      next if text.blank?

      type = row['type'].to_s.presence_in(TYPES) || 'open'
      { 'text' => text, 'type' => type, 'low' => low_for(type, row['low']) }.compact
    end
  end

  def low_for(type, raw)
    return unless DEFAULT_LOW.key?(type)

    max = type == 'scale5' ? 5 : 10
    (raw.presence || DEFAULT_LOW[type]).to_i.clamp(1, max)
  end

  # El texto que se pregunta tal cual: con su rango si no lo trae.
  def questions(items)
    items.map { |item| item['text'].match?(RANGE) || HINTS[item['type']].nil? ? item['text'] : "#{item['text']} #{HINTS[item['type']]}" }
  end

  def low_case(raw)
    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    { 'user_id' => raw['user_id'].to_s.presence&.to_i, 'team_id' => raw['team_id'].to_s.presence&.to_i,
      'case_type_id' => raw['case_type_id'].to_s.presence&.to_i,
      'priority' => raw['priority'].to_s.presence_in(PRIORITIES) || 'high' }.compact
  end

  # ¿Esa respuesta es baja? (número de pregunta desde 1). Sin preguntas con tipo: la regla de antes (menor a low_score).
  def low?(items, number, value, legacy_low)
    return false if value.nil? || value.to_s.strip.empty?

    item = Array(items)[number.to_i - 1]
    return value.to_i < legacy_low.to_i if item.nil?

    item['low'].present? && value.to_i < item['low'].to_i
  end
end
