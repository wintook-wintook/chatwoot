# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — EDITAR UNA SECCIÓN [X] DEL ENTRENAMIENTO, RENGLÓN POR RENGLÓN
# ================================================================================
# Lo comparten Ficha::Memory (variables) y Ficha::BusinessData (datos del negocio): el texto
# en @lines; buscar una sección, quitarle renglones, agregarle renglones (la crea al final
# si no existe) y quitarla completa. Mismo rótulo que el resto: «[NOMBRE]» solo en su línea.
# ================================================================================

module ContactTrackings::Ficha::SectionLines
  HEADER_RE = /\A[ \t]*\[([^\]\n]+)\][ \t]*\z/

  def text = @lines.join("\n").gsub(/\n{3,}/, "\n\n").strip

  private

  def section_range(titulo)
    inicio = @lines.index { |l| (m = l.match(HEADER_RE)) && same_title?(m[1], titulo) }
    return nil if inicio.nil?

    fin = ((inicio + 1)...@lines.size).find { |i| @lines[i].match?(HEADER_RE) } || @lines.size
    [inicio, fin]
  end

  def same_title?(uno, otro) = I18n.transliterate(uno.strip).casecmp?(I18n.transliterate(otro.strip))

  def section_body(titulo)
    rango = section_range(titulo)
    rango ? @lines[(rango[0] + 1)...rango[1]] : []
  end

  def drop_lines(titulo, &)
    rango = section_range(titulo)
    return if rango.nil?

    @lines[(rango[0] + 1)...rango[1]] = @lines[(rango[0] + 1)...rango[1]].reject(&)
  end

  def drop_section(titulo)
    rango = section_range(titulo)
    @lines.slice!(rango[0]...rango[1]) if rango
  end

  # La sección vacía (solo renglones en blanco) se quita.
  def drop_if_empty(titulo)
    rango = section_range(titulo)
    @lines.slice!(rango[0]...rango[1]) if rango && @lines[(rango[0] + 1)...rango[1]].all?(&:blank?)
  end

  def append_lines(titulo, lineas)
    return if lineas.empty?

    rango = section_range(titulo)
    return @lines.push('', "[#{titulo}]", *lineas) if rango.nil?

    ultima = (rango[0]...rango[1]).reverse_each.find { |i| @lines[i].present? }
    @lines.insert(ultima + 1, *lineas)
  end
end
