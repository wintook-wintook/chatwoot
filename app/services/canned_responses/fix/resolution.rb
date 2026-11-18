# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — RESOLVER UNA CONTRADICCIÓN: QUÉ SE QUITA Y QUÉ QUEDA
# ================================================================================
# La IA no puede saber cuál de dos datos es el correcto: lo elige la persona, por cada
# contradicción del hallazgo (CannedResponseFinding#details['contradictions']):
#
#   choice 'a'       A es correcto  → lo de B que A no dice queda prohibido
#   choice 'b'       B es correcto  → al revés
#   choice 'custom'  ninguno: `value` es el correcto → lo de las dos citas que no está en
#                    `value` queda prohibido, y `value` es obligatorio
#
# Se trabaja con los datos duros de cada cita (Fix::HardData): «$1,500» contra «$1,800».
# Si la contradicción no tiene datos duros («se requiere» contra «no se requiere»), lo
# prohibido es la cita perdedora entera.
#
# `wrong_data`: solo los datos duros prohibidos, para buscarlos en el resto de la cuenta
# (también ahí puede estar el dato equivocado).
# ================================================================================

class CannedResponses::Fix::Resolution
  CHOICES = %w[a b custom].freeze

  def initialize(contradictions, choices)
    @pairs = Array(contradictions).zip(Array(choices)).filter_map do |c, ch|
      next unless c.is_a?(Hash) && ch.is_a?(Hash) && CHOICES.include?(ch['choice'])

      [c, ch]
    end
  end

  def complete?(total) = @pairs.size == total

  # [{ 'kind', 'text', ('key') }]
  def forbidden = @forbidden ||= @pairs.flat_map { |c, ch| wrong_for(c, ch) }.uniq { |i| i['key'] || i['text'] }

  def required = @required ||= @pairs.flat_map { |c, ch| right_for(c, ch) }.uniq { |i| i['key'] || i['text'] }

  def wrong_data = forbidden.reject { |i| i['kind'] == 'sentence' }

  # Para el prompt de la IA: «cambia X por Y».
  def instructions
    @pairs.map do |c, ch|
      correcto = case ch['choice']
                 when 'a' then c['quote_a']
                 when 'b' then c['quote_b']
                 else ch['value']
                 end
      { 'topic' => c['topic'], 'quote_a' => c['quote_a'], 'quote_b' => c['quote_b'], 'correct' => correcto.to_s }
    end
  end

  def self.present?(item, text)
    return normalize(text).include?(normalize(item['text'])) if %w[sentence text].include?(item['kind'])

    CannedResponses::Fix::HardData.new(text).present?(item)
  end

  def self.normalize(texto) = ActiveSupport::Inflector.transliterate(texto.to_s).downcase.gsub(/\s+/, ' ').strip

  private

  def wrong_for(contradiccion, eleccion)
    a = contradiccion['quote_a'].to_s
    b = contradiccion['quote_b'].to_s
    case eleccion['choice']
    when 'a' then data_not_in(b, [a]).presence || [sentence(b)]
    when 'b' then data_not_in(a, [b]).presence || [sentence(a)]
    else
      valor = eleccion['value'].to_s
      data_not_in("#{a}\n#{b}", [valor]).presence || [a, b].reject do |q|
                                                       self.class.normalize(q) == self.class.normalize(valor)
                                                     end.map { |q| sentence(q) }
    end
  end

  def right_for(contradiccion, eleccion)
    case eleccion['choice']
    when 'a' then data_not_in(contradiccion['quote_a'].to_s, [contradiccion['quote_b'].to_s])
    when 'b' then data_not_in(contradiccion['quote_b'].to_s, [contradiccion['quote_a'].to_s])
    else
      valor = eleccion['value'].to_s.strip
      datos = CannedResponses::Fix::HardData.extract(valor)
      datos.presence || (valor.present? ? [{ 'kind' => 'text', 'text' => valor }] : [])
    end
  end

  # Los datos duros de `texto` que no aparecen en ninguno de `otros`.
  def data_not_in(texto, otros)
    CannedResponses::Fix::HardData.missing(texto, otros)
  end

  def sentence(texto) = { 'kind' => 'sentence', 'text' => texto.to_s }
end
