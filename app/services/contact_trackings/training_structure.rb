# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL ENTRENAMIENTO COMO LISTA DE BLOQUES
# ================================================================================
# Plan: docs/formulario_entrenamiento_plan.md. El formulario de la ficha del Agente IA
# edita el Entrenamiento sección por sección; esto convierte el texto en bloques y los
# bloques en texto.
#
#   routes    las líneas @ruta y @ruta_por_defecto
#   preamble  lo que va antes de la primera sección (en 8 de 28 agentes medidos, TODO)
#   section   un rótulo ([ROL], ## PERSONALIDAD) y su cuerpo
#
# INVARIANTE: compose(parse(texto)) == texto, carácter por carácter. Abrir un agente en
# el formulario y guardarlo sin tocar nada no cambia lo que lee el motor. Por eso cada
# bloque guarda sus renglones en blanco del final (`gap`) y cada sección su rótulo
# original (`header`): "## PERSONALIDAD ##" vuelve tal cual, no como "## PERSONALIDAD".
#
# El corte lo hace DraftPieces, el mismo que usa el Asistente para su diff: si cada
# uno cortara distinto, "qué cambió" y el formulario dirían cosas distintas.
# ================================================================================

module ContactTrackings::TrainingStructure
  VERSION = 1
  TYPES = %w[routes preamble section].freeze
  STYLES = %w[bracket markdown1 markdown2 markdown3].freeze
  Pieces = ContactTrackings::Assistant::DraftPieces

  module_function

  def parse(text)
    { 'version' => VERSION, 'blocks' => groups(text.to_s).map { |grupo| block(grupo) } }
  end

  def compose(structure)
    Array((structure || {})['blocks'] || (structure || {})[:blocks]).filter_map { |b| block_text(b.stringify_keys) }.join("\n")
  end

  # ── texto → bloques ─────────────────────────────────────────────────────────
  # Los tramos de DraftPieces, agrupados: ramas seguidas en un solo bloque, y los
  # renglones en blanco sueltos pegados al bloque anterior.
  def groups(text)
    Pieces.new(text).chunks.each_with_object([]) do |chunk, grupos|
      tipo = type_of(chunk)
      ultimo = grupos.last
      if ultimo && (chunk.lines.all?(&:blank?) || same_group?(ultimo, tipo, chunk))
        ultimo[:lines].concat(chunk.lines)
      else
        grupos << { type: tipo, key: chunk.key, lines: chunk.lines.dup }
      end
    end
  end

  def type_of(chunk)
    return 'routes' if chunk.route || chunk.key == Pieces::DEFAULT_KEY
    return 'preamble' if chunk.key == Pieces::PREAMBLE_KEY

    'section'
  end

  # Una @ruta escrita en medio de una sección queda en el cuerpo de esa sección, donde
  # la escribió la persona (el motor las lee en cualquier parte del texto). Sin esto,
  # lo que sigue debajo quedaba como un bloque sin rótulo y el texto no volvía igual.
  def same_group?(grupo, tipo, chunk)
    return grupo[:key] == chunk.key || tipo == 'routes' if grupo[:type] == 'section'

    grupo[:type] == tipo
  end

  def block(grupo)
    lineas = grupo[:lines]
    gap = lineas.reverse.take_while(&:blank?).size
    contenido = lineas.first(lineas.size - gap)
    return { 'type' => grupo[:type], 'text' => contenido.join("\n"), 'gap' => gap } unless grupo[:type] == 'section'

    titulo, estilo = header_parts(contenido.first)
    { 'type' => 'section', 'title' => titulo, 'style' => estilo, 'header' => contenido.first,
      'body' => contenido.drop(1).join("\n"), 'gap' => gap }
  end

  # [título, estilo] de una línea de rótulo, o nil.
  def header_parts(linea)
    if (m = linea.to_s.match(Pieces::SECTION_RE))
      [m[1].strip, 'bracket']
    elsif (m = linea.to_s.match(Pieces::MARKDOWN_RE))
      [m[2].strip, "markdown#{m[1].size}"]
    end
  end

  # ── bloques → texto ─────────────────────────────────────────────────────────
  def block_text(bloque)
    return nil unless TYPES.include?(bloque['type'])

    lineas = content_lines(bloque) + Array.new(bloque['gap'].to_i.clamp(0, 50), '')
    lineas.join("\n")
  end

  def content_lines(bloque)
    if bloque['type'] == 'section'
      cuerpo = bloque['body'].to_s.sub(/\n+\z/, '')
      [header_for(bloque)] + (cuerpo.empty? ? [] : cuerpo.split("\n", -1))
    else
      texto = bloque['text'].to_s.sub(/\n+\z/, '')
      texto.empty? ? [] : texto.split("\n", -1)
    end
  end

  # El rótulo original si sigue diciendo lo mismo; si no, uno nuevo en su estilo. Un
  # título con saltos de línea o corchetes se limpia: rompería el rótulo.
  def header_for(bloque)
    titulo = bloque['title'].to_s.gsub(/[\[\]\n\r]/, ' ').squish
    estilo = STYLES.include?(bloque['style']) ? bloque['style'] : 'bracket'
    return bloque['header'] if bloque['header'].present? && header_parts(bloque['header']) == [titulo, estilo]

    estilo == 'bracket' ? "[#{titulo}]" : "#{'#' * estilo[-1].to_i} #{titulo}"
  end
end
