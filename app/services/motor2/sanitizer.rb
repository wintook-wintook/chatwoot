# frozen_string_literal: true

# Motor 2.0 — limpia lo que manda la pantalla para tracking_templates.motor2: solo las llaves
# que conoce el motor, textos con tope y listas con tope.
module Motor2::Sanitizer
  TEXTS = { 'instructions' => 6000, 'welcome' => 1500, 'never' => 2000 }.freeze
  SKILL_KEYS = {
    'data' => %w[on fields], 'offers' => %w[on objection steps], 'appointments' => %w[on kind location when],
    'tickets' => %w[on types priority], 'files' => %w[on], 'handoff' => %w[on when user_id team_id]
  }.freeze

  module_function

  def call(raw)
    raw = plain(raw)
    out = TEXTS.to_h { |key, max| [key, raw[key].to_s.strip.first(max)] }
    out.merge('tone' => raw['tone'].to_s.presence_in(Motor2::Config::TONES) || 'tu',
              'business' => list(raw['business'], 30) { |r| row(r) },
              'sources' => Array(raw['sources']).map(&:to_s).compact_blank.uniq.first(30),
              'skills' => skills(plain(raw['skills'])))
  end

  def skills(raw)
    SKILL_KEYS.to_h do |key, allowed|
      skill = plain(raw[key]).slice(*allowed)
      skill['on'] = ActiveModel::Type::Boolean.new.cast(skill['on']) if skill.key?('on')
      [key, clean_skill(key, skill)]
    end
  end

  def clean_skill(key, skill)
    case key
    when 'data' then skill.merge('fields' => list(skill['fields'], 15) { |f| field(f) })
    when 'offers' then skill.merge('objection' => text(skill['objection'], 300), 'steps' => list(skill['steps'], 8) { |s| step(s) })
    when 'tickets' then skill.merge('types' => list(skill['types'], 10) { |t| case_type(t) })
    else skill.transform_values { |v| v.is_a?(String) ? v.strip.first(300) : v }
    end
  end

  def step(raw)
    { 'text' => text(raw['text'], 800), 'file' => text(raw['file'], 100) } if raw['text'].present?
  end

  def case_type(raw)
    { 'case_type_id' => raw['case_type_id'].to_i, 'when' => text(raw['when'], 200) } if raw['case_type_id'].to_i.positive?
  end

  def row(raw)
    { 'label' => text(raw['label'], 80), 'value' => text(raw['value'], 500) } if raw['label'].present? && raw['value'].present?
  end

  def field(raw)
    key = raw['key'].to_s.parameterize(separator: '_').first(40)
    return if key.blank?

    { 'key' => key, 'label' => text(raw['label'], 120), 'ask' => ActiveModel::Type::Boolean.new.cast(raw['ask']) || false,
      'values' => Array(raw['values']).map { |v| text(v, 80) }.compact_blank.uniq.first(30),
      'resets' => Array(raw['resets']).map(&:to_s).compact_blank.first(5) }
  end

  def list(raw, max)
    Array(raw).first(max).filter_map { |item| yield(plain(item)) }
  end

  def text(value, max) = value.to_s.strip.first(max)

  def plain(value)
    value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
    value.is_a?(Hash) ? value.deep_stringify_keys : {}
  end
end
