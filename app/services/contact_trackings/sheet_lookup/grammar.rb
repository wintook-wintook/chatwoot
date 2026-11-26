# frozen_string_literal: true

# proyecto@hoja_buscar — leer la directiva: {{hoja_buscar: Hoja | buscar | regresar | orden}}.
# Las constantes y los Struct viven en ContactTrackings::SheetLookup (aquí: L).
module ContactTrackings::SheetLookup::Grammar
  # Todas las directivas bien escritas de un texto. Una mal escrita (le falta una de las
  # tres partes) no se devuelve: la marca el comprobador.
  def parse_all(text)
    text.to_s.scan(L::DIRECTIVE_RE).filter_map { |(inner)| parse(inner) }
  end

  def parse(inner)
    parts = inner.to_s.split('|', -1).map(&:strip)
    return nil unless well_formed?(parts)

    sheet, where, returns, orden = parts
    filters = parse_filters(where)
    order = parse_order(orden)
    return nil if filters.nil? || order == :invalid

    L::Spec.new(sheet: sheet, filters: filters, returns: returns.split(',').map(&:strip).compact_blank, order: order)
  end

  private

  L = ContactTrackings::SheetLookup

  # Hoja, buscar y regresar, y el orden si viene; ninguna parte vacía.
  def well_formed?(parts)
    parts.size.between?(3, 4) && parts.all?(&:present?)
  end

  # nil sin «orden:»; :invalid si está mal escrito.
  def parse_order(text)
    return nil if text.nil?

    _, column, direction, limit = text.match(L::ORDER_RE).to_a
    return :invalid if column.blank?

    L::Order.new(column: column.strip, direction: direction.downcase, limit: limit&.to_i&.nonzero?)
  end

  # nil si alguna condición está mal escrita (sin «=» o sin valor). «*» = sin condiciones.
  def parse_filters(where)
    return [] if where == L::ALL_ROWS

    filters = where.split(';').map(&:strip).compact_blank.map { |cond| parse_filter(cond) }
    filters if filters.any? && filters.none?(&:nil?)
  end

  def parse_filter(cond)
    _, column, op, wanted = cond.match(L::OPERATOR_RE).to_a.map { |part| part.to_s.strip }
    return nil if column.blank? || wanted.blank?
    return ask_filter(column, op, wanted) if ask_word?(wanted)
    return numeric_filter(column, op, wanted) if L::NUMERIC_OPS.include?(op)

    L::Filter.new(column: column, op: op, wanted: wanted.split(',').map(&:strip).compact_blank)
  end

  def ask_word?(wanted) = wanted.casecmp?(L::ASK) || wanted.casecmp?(L::ASK_OPTIONAL)

  # «?» u «?opcional»: el valor sale de la conversación.
  def ask_filter(column, operator, wanted)
    L::Filter.new(column: column, op: operator, wanted: L::ASK, optional: wanted.casecmp?(L::ASK_OPTIONAL))
  end

  # «capacidad_t>=40»: un solo número. «>=grande» no es una condición válida.
  def numeric_filter(column, operator, wanted)
    numero = ContactTrackings::SheetNumbers.cell(wanted)
    numero && L::Filter.new(column: column, op: operator, wanted: [numero])
  end
end
