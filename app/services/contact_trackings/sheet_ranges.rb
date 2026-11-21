# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — RANGOS «ENTRE X Y Y» (21/11/2026, Seminuevos Valera)
# ================================================================================
# «¿Algún auto entre 100 mil y 200 mil?» con PRECIO<=?: SheetNumbers daba los dos números y
# «<=» tomaba el menor (100 mil): no salía nada y el agente inventó opciones. Con un rango
# dicho así, la condición numérica de esa columna se vuelve «entre los dos», sea >= o <=.
#
#   «entre 100 mil y 200 mil», «de 150 a 250 mil», «desde $120,000 hasta $180,000»
#   «entre 2018 y 2020», «del 2018 al 2021»
#
# Solo dinero y año: en toneladas «grúa de 80 t para una carga de 26 t» no es un rango, y
# capacidad>=? sigue tomando el mayor (ver SheetLookup#mentioned_number).
# En «de 150 a 250 mil» el primero toma la unidad del segundo; el segundo tiene que ser
# dinero por sí solo («de 200 mil y 2020» no es rango).
# ================================================================================
module ContactTrackings::SheetRanges
  N = ContactTrackings::SheetNumbers::NUMBER
  UNIT = '(?:mil(?:l[oó]n(?:es)?)?|k|millones|mdp)'
  MONEY_AMOUNT = "\\$?\\s*#{N}(?:\\s*(#{UNIT}))?".freeze
  MONEY_RANGE_RE = /\b(?:entre|de|desde)\s+(#{MONEY_AMOUNT})\s*(?:y|a|al|hasta|-)\s*(#{MONEY_AMOUNT})(?![[:alnum:]])/i
  YEAR = '((?:19[5-9]|20[0-4])\d)'
  YEAR_RANGE_RE = /\b(?:entre|del?|desde)\s+(?:el\s+)?#{YEAR}\s*(?:y|a|al|hasta|-)\s*(?:el\s+)?#{YEAR}(?![\d.,])/i

  module_function

  # Lo que pide el texto para una condición numérica: el rango si lo dio; si no, con «>=» el
  # mayor número que dijo y con «<=» el menor. nil si no trae número.
  def wanted(text, filter)
    rango = in_text(text, filter.column)
    return Range.new(*rango) if rango

    numeros = ContactTrackings::SheetNumbers.in_text(text, filter.column)
    return nil if numeros.empty?

    filter.op.start_with?('>') ? numeros.max : numeros.min
  end

  # [menor, mayor] si el texto da un rango para esa columna; si no, nil.
  def in_text(text, column)
    case ContactTrackings::SheetNumbers.kind(column)
    when :money then money(text.to_s)
    when :year
      m = text.to_s.match(YEAR_RANGE_RE)
      m && [m[1].to_i, m[2].to_i].sort
    end
  end

  # Grupos: 1 = primera cantidad (2 número, 3 unidad), 4 = segunda (5 número, 6 unidad).
  def money(text)
    m = text.match(MONEY_RANGE_RE)
    alto = m && ContactTrackings::SheetNumbers.money(m[4]).first
    return nil if alto.nil?

    bajo = ContactTrackings::SheetNumbers.money(m[1]).first
    bajo ||= ContactTrackings::SheetNumbers.with_unit(m[2], m[6]) if m[6]
    bajo && [bajo, alto].sort
  end

  # Una celda sin número no cumple ninguna comparación; con rango, entre los dos.
  def within?(operator, value, threshold)
    return false if value.nil?
    return threshold.cover?(value) if threshold.is_a?(Range)

    value.public_send(operator, threshold)
  end
end
