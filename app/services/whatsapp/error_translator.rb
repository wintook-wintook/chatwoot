# frozen_string_literal: true

# diag/waba F1 — traduce el error que Meta dejó en un mensaje fallido (`external_error`) a algo
# que el usuario entienda. Llega en dos formas:
#   «131047: Re-engagement message»                         (aviso de estado de Meta)
#   '{"error":{"message":"…","type":"OAuthException","code":190}}'  (respuesta del envío)
#
#   Whatsapp::ErrorTranslator.translate(text) → { key:, code:, text: }
class Whatsapp::ErrorTranslator
  KEYS = {
    'window_24h' => [131_047, 470],
    'not_on_whatsapp' => [131_026],
    'payment' => [131_042],
    'ecosystem' => [131_049, 131_050],
    'unsupported' => [131_051],
    'template' => (132_000..132_016).to_a,
    'rate_limit' => [130_429, 131_056, 80_007],
    'token' => [190, 401],
    'blocked' => [131_031, 368]
  }.freeze

  CODE_TO_KEY = KEYS.flat_map { |key, codes| codes.map { |c| [c, key] } }.to_h.freeze

  def self.translate(raw)
    new(raw).translate
  end

  def initialize(raw)
    @raw = raw.to_s
  end

  def translate
    code, title = parse
    key = CODE_TO_KEY[code] || 'other'
    text = I18n.t("whatsapp_health.errors.#{key}", title: title.presence || I18n.t('whatsapp_health.errors.no_title'))
    { key: key, code: code, text: text }
  end

  private

  def parse
    json = parse_json
    if json
      error = json['error'] || {}
      details = error.dig('error_data', 'details')
      return [error['code'].to_i.nonzero?, details.presence || error['message']]
    end

    match = @raw.match(/\A\s*(\d+)\s*:\s*(.*)\z/m)
    match ? [match[1].to_i, match[2].strip] : [nil, @raw.first(120)]
  end

  def parse_json
    return nil unless @raw.lstrip.start_with?('{')

    parsed = JSON.parse(@raw)
    parsed.is_a?(Hash) ? parsed : nil
  rescue JSON::ParserError
    nil
  end
end
