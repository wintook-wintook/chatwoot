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
#   toneladas (_t, ton, peso,       t, tn, tns, ton, tons, toneladas, kg  «26 toneladas» → 26
#   capacidad)                      (÷ 1000)                        «8,800 kg»     → 8.8
#   metros (_m, largo, ancho,       m, mt, mts, mtr, mtrs, metros   «plana de 12 mts» → 12
#   alto, altura)
#   año (año, anio, year, modelo)   un año de 4 dígitos, sin unidad «del 2020 en adelante» → 2020
#                                                                   «2022 para arriba» → 2022
#   dinero (precio, costo, monto,   «mil», «k», «millón», $ o miles «menos de 200 mil» → 200000
#   importe, tarifa, price)         separados; un número suelto     «hasta $250,000»   → 250000
#                                   solo si tiene 5+ dígitos        «1.5 millones»     → 1500000
#   cualquier otra                  la palabra de la columna        «5 extensiones» → 5
#                                                                   (columna extensiones)
#
# Año (20/11/2026, Seminuevos Valera): la columna MODELO es el año del auto y el cliente no
# escribe «2020 modelo» sino «del 2020», «2022 para arriba», «más nuevo que 2021». El
# operador lo pone la ruta (MODELO>=?); aquí solo se lee el año. Igual con el dinero
# («menos de 200 mil» con PRECIO<=?): un «2020» suelto no es un precio, así el año que
# también dijo el cliente no se toma como tope.
# Las celdas se leen igual: «40.8» → 40.8, «1,100» → 1100, «12,5» → 12.5.
# ================================================================================

module ContactTrackings::SheetNumbers
  NUMBER = '(\d{1,3}(?:[.,]\d{3})+(?![.,]?\d)|\d+(?:[.,]\d+)?)'
  TONS_RE   = /#{NUMBER}\s*(toneladas?|tons?|tns|tn|t)(?![[:alnum:]])/i
  KILOS_RE  = /#{NUMBER}\s*(kilogramos?|kilos?|kgs?)(?![[:alnum:]])/i
  METERS_RE = /#{NUMBER}\s*(metros?|mtrs?|mts?|m)(?![[:alnum:]])/i
  MONEY_UNIT_RE = /#{NUMBER}\s*(mil(?:l[oó]n(?:es)?)?|k|millones|mdp)(?![[:alnum:]])/i
  MONEY_SIGN_RE = /\$\s*#{NUMBER}/
  MONEY_PLAIN_RE = /(?<![\d.,$])(\d{1,3}(?:[,. ]\d{3})+|\d{5,8})(?![.,]?\d)(?!\s*(?:mil|k|millones|mdp)\b)/i
  HALF_MILLION_RE = /medio\s+mill[oó]n/i
  # 1950–2049 suelto: no pegado a otros dígitos, ni parte de un precio («$2,020», «2020 mil»).
  YEAR_RE = /(?<![\d.,$])((?:19[5-9]|20[0-4])\d)(?![.,]?\d)(?!\s*(?:mil|k|pesos)\b)/i

  module_function

  def kind(column)
    col = column.to_s.downcase
    return :tons if col.match?(/(\A|_)t\z|ton|peso|capacidad/)
    return :meters if col.match?(/(\A|_)m\z|metro|largo|ancho|alto/)
    return :money if col.match?(/precio|costo|monto|importe|tarifa|price|valor/)
    return :year if I18n.transliterate(col).match?(/\A(ano|anio|year|modelo)\z|(\A|_)(ano|anio|year)(_|\z)/)

    :other
  end

  # Todos los números de un texto que se pueden comparar contra esa columna.
  def in_text(text, column)
    texto = text.to_s
    case kind(column)
    when :tons then scan(texto, TONS_RE) + scan(texto, KILOS_RE).map { |kg| kg / 1000.0 }
    when :meters then scan(texto, METERS_RE)
    when :year then texto.scan(YEAR_RE).map { |(anio)| anio.to_i }
    when :money then money(texto)
    else scan(texto, /#{NUMBER}\s*#{Regexp.escape(stem(column))}/i)
    end
  end

  # Cantidades de dinero en el orden en que aparecen: «200 mil», «200k», «$250,000»,
  # «250 000», «1.5 millones», «medio millón».
  def money(texto)
    found = matches(texto, MONEY_UNIT_RE) { |m| with_unit(*m.captures) } +
            matches(texto, MONEY_SIGN_RE) { |m| number(m[1]) } +
            matches(texto, MONEY_PLAIN_RE) { |m| number(m[1].delete(' ')) } +
            matches(texto, HALF_MILLION_RE) { 500_000.0 }
    found.sort_by(&:first).filter_map(&:last).uniq
  end

  # [[posición, valor]] de cada coincidencia, para devolverlas en el orden del texto.
  def matches(texto, regex)
    texto.to_enum(:scan, regex).map { [Regexp.last_match.begin(0), yield(Regexp.last_match)] }
  end

  def with_unit(raw, unit)
    base = number(raw)
    return nil if base.nil?

    unit.to_s.downcase.match?(/mill|mdp/) ? base * 1_000_000 : base * 1000
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

  # ¿El texto nombra el valor? «TP-64», «tp 64» y «TP64» son el mismo remolque; «TP-6» no es
  # «TP-64». Sin acentos: «grua» es «Grúa». Lo usa {{hoja_buscar:}} con «?».
  def names?(text, value)
    parts = fold(value).scan(/[[:alnum:]]+/)
    return false if parts.empty?

    fold(text).match?(/(?<![[:alnum:]])#{parts.map { |p| Regexp.escape(p) }.join('[\s\-_.]*')}(?![[:alnum:]])/)
  end
end
