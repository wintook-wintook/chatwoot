# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — NÚMEROS PARA COMPARAR CONTRA UNA HOJA (pieza 1, 26/09/2026)
# ================================================================================
# {{hoja_buscar: Equipos | capacidad_t>=? | Calendar_ID}}: el «?» es un número que dijo
# el cliente. Sin IA: se buscan números CON UNIDAD en su mensaje, y la unidad tiene que
# ser la de la columna — si no, «el lunes 28 a las 10» daría 28 toneladas.
#
#   columna                         acepta                          ejemplo → valor
#   ─────────────────────────────── ─────────────────────────────── ─────────────────────
#   toneladas (_t, ton, peso,       t, ton, tons, toneladas, kg     «26 toneladas» → 26
#   capacidad)                      (÷ 1000)                        «8,800 kg»     → 8.8
#   metros (_m, largo, ancho,       m, mts, metros                  «plana de 12 mts» → 12
#   alto, altura)
#   cualquier otra                  la palabra de la columna        «5 extensiones» → 5
#                                                                   (columna extensiones)
#
# Las celdas se leen igual: «40.8» → 40.8, «1,100» → 1100, «12,5» → 12.5.
# ================================================================================

module ContactTrackings::SheetNumbers
  NUMBER = '(\d{1,3}(?:[.,]\d{3})+(?![.,]?\d)|\d+(?:[.,]\d+)?)'
  TONS_RE   = /#{NUMBER}\s*(toneladas?|tons?|tn|t)(?![[:alnum:]])/i
  KILOS_RE  = /#{NUMBER}\s*(kilogramos?|kilos?|kgs?)(?![[:alnum:]])/i
  METERS_RE = /#{NUMBER}\s*(metros?|mts?|m)(?![[:alnum:]])/i

  module_function

  def kind(column)
    col = column.to_s.downcase
    return :tons if col.match?(/(\A|_)t\z|ton|peso|capacidad/)
    return :meters if col.match?(/(\A|_)m\z|metro|largo|ancho|alto/)

    :other
  end

  # Todos los números de un texto que se pueden comparar contra esa columna.
  def in_text(text, column)
    texto = text.to_s
    case kind(column)
    when :tons then scan(texto, TONS_RE) + scan(texto, KILOS_RE).map { |kg| kg / 1000.0 }
    when :meters then scan(texto, METERS_RE)
    else scan(texto, /#{NUMBER}\s*#{Regexp.escape(stem(column))}/i)
    end
  end

  # El primer número de una celda, o nil si no tiene.
  def cell(value)
    number(value.to_s[/#{NUMBER}/o, 1])
  end

  def number(raw)
    return nil if raw.blank?
    return raw.delete(',.').to_f if raw.match?(/\A\d{1,3}(?:[.,]\d{3})+\z/)

    raw.tr(',', '.').to_f
  end

  def scan(text, regex)
    text.scan(regex).filter_map { |(raw, _unit)| number(raw) }
  end

  # «extensiones» → «extensi»: acepta «extensión» y «extensiones».
  def stem(column)
    ContactTrackings::SheetNumbers.fold(column.to_s.split(/[_\s]/).last.to_s)[0, 7]
  end

  def fold(text)
    I18n.transliterate(text.to_s).downcase
  end
end
