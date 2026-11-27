# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — LOS DATOS DUROS QUE NO SE PUEDEN PERDER
# ================================================================================
# Al dividir o condensar con IA, el error típico no es de redacción: es que se cae un
# precio, una fecha o un teléfono. Esto saca del texto todo dato concreto, sin saber de
# qué trata la cuenta, y dice cuáles del original no aparecen en la propuesta.
#
#   url, email, phone (8+ dígitos), money ($ / MXN / USD / pesos / dólares…), percent,
#   time (9:00, 18:30), date (12/05/2026, 3 de mayo), code (LIC-DER, SAE-2025),
#   number (de 3 o más dígitos), quantity (número + palabra: «3 años», «9 cuatrimestres»,
#   «15 días hábiles»), variable ({{contact.name}})
#
# Cada dato se compara normalizado (sin acentos, minúsculas, sin espacios dentro de
# montos): «$ 1,500» y «$1500» son el mismo dato. Un teléfono se compara por sus dígitos.
# ================================================================================

class CannedResponses::Fix::HardData
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre setiembre octubre noviembre diciembre
              january february march april may june july august september october november december].freeze
  PATTERNS = {
    'url' => %r{\b(?:https?://|www\.)[^\s<>()\[\]"'«»]+}i,
    'email' => /\b[\w.+-]+@[\w-]+(?:\.[\w-]+)+\b/,
    'variable' => /\{\{\s*[\w.]+\s*\}\}/,
    'money' => /(?:\$\s?\d[\d.,]*|\b\d[\d.,]*\s?(?:mxn|usd|eur|pesos|d[oó]lares|euros)\b)/i,
    'percent' => /\b\d+(?:[.,]\d+)?\s?%/,
    'time' => /\b\d{1,2}:\d{2}\b/,
    'date' => %r{\b\d{1,2}/\d{1,2}/\d{2,4}\b|\b\d{1,2}\s+de\s+(?:#{MONTHS.join('|')})\b}i,
    'phone' => /(?:\+?\d[\d\s().-]{7,}\d)/,
    'code' => /\b[A-Z][A-Z0-9]{0,7}(?:-[A-Z0-9]{1,10})+\b/,
    # Hasta 3 dígitos: «2025 siga» es un año seguido de una palabra, no una cantidad (el
    # año ya cuenta como número).
    'quantity' => /\b\d{1,3}(?:[.,]\d+)?\s+\p{L}{3,}(?:\s+h[aá]biles)?/i,
    'number' => /\b\d{3,}\b/
  }.freeze

  def self.extract(text) = new(text).items

  # Los del original que no aparecen en ninguno de los textos nuevos: [{ 'kind', 'text', 'key' }]
  def self.missing(original, new_texts)
    nuevo = new(Array(new_texts).join("\n\n"))
    extract(original).reject { |item| nuevo.present?(item) }
  end

  # ¿El dato está en este texto? Por presencia y no por tipo: el mismo dato puede caer
  # en otra categoría al reescribirse («RVOE 20181311» es número o código).
  def present?(item)
    case item['kind']
    when 'phone' then compact.include?(item['key'].delete_prefix('phone:'))
    when 'money' then money_keys.include?(item['key']) || normalized.include?(normalize(item['text']))
    when 'url' then normalized.include?(item['key'].delete_prefix('url:'))
    when 'percent' then normalized.delete(' ').include?(normalize(item['text']).delete(' '))
    else normalized.include?(normalize(item['text']))
    end
  end

  def initialize(text)
    @text = text.to_s
  end

  # [{ 'kind', 'text', 'key' }] sin repetir.
  def items
    vistos = Set.new
    PATTERNS.flat_map do |kind, re|
      @text.scan(re).map { |m| m.is_a?(Array) ? m.first : m }.filter_map do |texto|
        texto = texto.to_s.strip.sub(/[.,;:]+\z/, '')
        next if skip?(kind, texto)

        clave = key(kind, texto)
        { 'kind' => kind, 'text' => texto, 'key' => clave } if vistos.add?(clave)
      end
    end
  end

  def keys = items.to_set { |i| i['key'] }

  private

  def normalize(texto) = ActiveSupport::Inflector.transliterate(texto.to_s).downcase.gsub(/\s+/, ' ').strip
  def normalized = @normalized ||= normalize(@text)
  def compact = @compact ||= @text.gsub(/[\s().+-]/, '')
  def money_keys = @money_keys ||= items.select { |i| i['kind'] == 'money' }.to_set { |i| i['key'] }

  # Un «teléfono» de menos de 8 dígitos es otra cosa (un rango, un monto); un «número»
  # que ya es parte de un teléfono, monto, fecha u hora no se cuenta dos veces.
  def skip?(kind, texto)
    case kind
    when 'phone' then texto.scan(/\d/).size < 8
    when 'number' then covered_number?(texto)
    else false
    end
  end

  def covered_number?(texto)
    @covered ||= %w[phone money date time code url].flat_map { |k| @text.scan(PATTERNS[k]) }.join(' ')
    @covered.include?(texto)
  end

  def key(kind, texto)
    base = ActiveSupport::Inflector.transliterate(texto).downcase
    case kind
    when 'phone' then "phone:#{base.gsub(/\D/, '').last(10)}"
    when 'money' then "money:#{base.gsub(/[\s,]/, '').sub(/\.00\z/, '')}"
    when 'percent' then "percent:#{base.delete(' ')}"
    when 'url' then "url:#{base.sub(%r{\Ahttps?://}, '').sub(/\Awww\./, '').chomp('/')}"
    else "#{kind}:#{base.gsub(/\s+/, ' ')}"
    end
  end
end
