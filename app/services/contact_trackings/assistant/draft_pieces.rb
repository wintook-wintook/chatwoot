# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — UN ENTRENAMIENTO CORTADO EN PIEZAS
# ================================================================================
# Las piezas son las que ve quien edita: cada @ruta, la @ruta_por_defecto, cada
# [SECCIÓN] de la prosa (sea cual sea el rótulo) y la prosa suelta antes del primer
# rótulo. Cada una guarda su TEXTO ORIGINAL, línea por línea.
#
# Existe para dos cosas, que necesitan el mismo corte:
#   DraftDiff  comparar dos Entrenamientos pieza por pieza
#   restore    devolverle a un Entrenamiento del asistente las piezas que la persona
#              había editado a mano, sin tocar el resto de lo que el asistente cambió
#
# El corte es por líneas y se puede rearmar: `to_s` devuelve el texto de entrada tal
# cual. Una @ruta en medio de una sección es su propia pieza; lo que sigue debajo
# vuelve a ser de esa sección.
#
# LOS DOS FORMATOS DE SECCIÓN (medido 17/09/2026 sobre los 28 prompts del respaldo de
# la cuenta 2: 7 con [X], 7 con Markdown, 6 con los dos, 8 sin secciones):
#   [ROL]          siempre es una sección
#   ## ROL         es sección si es el nivel de encabezado MÁS ALTO del texto; los más
#                  bajos (### debajo de ##) quedan dentro de su sección — son subtítulos
#                  como "A. COINCIDENCIA EXACTA", que no se separan de su regla
#   # TÍTULO       un único # al principio es el título del prompt: va al texto inicial
# Los encabezados dentro de un bloque de código (```) no cuentan.
# ================================================================================

class ContactTrackings::Assistant::DraftPieces
  SECTION_RE = /\A[ \t]*\[([^\]\n]+)\][ \t]*\z/
  MARKDOWN_RE = /\A[ \t]{0,3}(\#{1,3})[ \t]+(\S.*?)[ \t]*\#*[ \t]*\z/
  FENCE_RE = /\A[ \t]*```/
  DEFAULT_KEY = '@ruta_por_defecto'
  PREAMBLE_KEY = '(sin sección)'

  # Un tramo de líneas seguidas de una misma pieza.
  Chunk = Struct.new(:key, :label, :route, :lines, keyword_init: true)
  Piece = Struct.new(:key, :label, :route, :value, :raw, keyword_init: true)

  def self.normalize_key(key)
    key.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase.gsub(/\s+/, ' ').strip
  end

  # Le devuelve a `theirs` las piezas `keys` tal como están en `mine`: si en `mine`
  # existen se ponen en su lugar, y si no existen se quitan.
  def self.restore(theirs:, mine:, keys:)
    destino = new(theirs)
    origen = new(mine)
    Array(keys).each { |key| destino.put(normalize_key(key), origen) }
    destino.to_s
  end

  def initialize(text)
    @chunks = segment(text.to_s)
  end

  def to_s
    @chunks.flat_map(&:lines).join("\n")
  end

  # { clave_normalizada => Piece }, en orden de aparición. La prosa suelta en blanco
  # no es una pieza: son los renglones vacíos entre las rutas y el primer rótulo.
  def pieces
    @chunks.group_by(&:key).each_with_object({}) do |(key, tramos), acc|
      piece = build_piece(key, tramos)
      acc[key] = piece unless key == PREAMBLE_KEY && piece.value.blank?
    end
  end

  def keys_in_order
    @chunks.map(&:key).uniq
  end

  # Los tramos en orden, para quien necesita el texto original línea por línea
  # (TrainingStructure). Copia: nadie de afuera modifica el corte.
  def chunks
    @chunks.map(&:dup)
  end

  def chunks_for(key)
    @chunks.select { |chunk| chunk.key == key }
  end

  # Pone la pieza `key` de `origen` en este texto (ver .restore).
  def put(key, origen)
    tramos = origen.chunks_for(key)
    return @chunks.reject! { |chunk| chunk.key == key } if tramos.empty?

    nuevo = Chunk.new(key: key, label: tramos.first.label, route: tramos.first.route, lines: tramos.flat_map(&:lines))
    indice = @chunks.index { |chunk| chunk.key == key }
    @chunks.reject! { |chunk| chunk.key == key }
    @chunks.insert(indice || insertion_point(key, origen), nuevo)
  end

  private

  # Una pieza que no estaba va detrás de la que la precede en el texto de origen.
  def insertion_point(key, origen)
    orden = origen.keys_in_order
    anteriores = orden.take(orden.index(key).to_i).reverse
    ancla = anteriores.find { |previa| @chunks.any? { |chunk| chunk.key == previa } }
    return 0 if ancla.nil?

    @chunks.rindex { |chunk| chunk.key == ancla } + 1
  end

  def build_piece(key, tramos)
    primero = tramos.first
    lineas = tramos.flat_map(&:lines)
    value = if primero.route
              route_value(lineas.first)
            elsif key == DEFAULT_KEY
              lineas.first[ContactTrackings::RouteMap::DEFAULT_RE, 1].to_s.downcase
            else
              body(key, lineas).join("\n").squish
            end

    Piece.new(key: key, label: primero.label, route: primero.route, value: value, raw: lineas.join("\n"))
  end

  # El rótulo no es contenido: dos secciones iguales con otro rótulo ya son otra clave.
  def body(key, lineas)
    key == PREAMBLE_KEY ? lineas : lineas.drop(1)
  end

  def route_value(line)
    route = ContactTrackings::RouteMap.parse(line).routes.first
    route.to_h.transform_values { |v| v.to_s.squish }
  end

  def segment(text)
    chunks = []
    seccion = nil
    vistas = Hash.new(0)
    lineas = text.split("\n", -1)
    @markdown_sections = markdown_section_lines(lineas)

    lineas.each_with_index do |line, indice|
      pieza = line_piece(line, vistas, indice)
      if pieza
        seccion = pieza if pieza[:section]
        append(chunks, pieza[:key], pieza[:label], pieza[:route], line)
      else
        actual = seccion || { key: PREAMBLE_KEY, label: PREAMBLE_KEY, route: false }
        append(chunks, actual[:key], actual[:label], false, line)
      end
    end

    chunks
  end

  # La pieza que ABRE esta línea, o nil si la línea sigue a la pieza en curso.
  def line_piece(line, vistas, indice = nil)
    if (match = line.match(ContactTrackings::RouteMap::LINE_RE))
      label = "@ruta(#{match[1].strip.downcase})"
      { key: unique_key(label, vistas), label: label, route: true }
    elsif ContactTrackings::TrainingRoutes.broken?(line)
      # Una rama mal escrita sigue siendo una rama para quien la lee: va con las demás
      # (y en el árbol, como rota), no escondida en el cuerpo de una sección.
      label = "@ruta(#{ContactTrackings::TrainingRoutes.broken_entry(line)['name']})"
      { key: unique_key(label, vistas), label: label, route: true }
    elsif line.match?(ContactTrackings::RouteMap::DEFAULT_RE)
      { key: unique_key(DEFAULT_KEY, vistas), label: DEFAULT_KEY, route: false }
    elsif (match = line.match(SECTION_RE))
      label = "[#{match[1].strip}]"
      { key: unique_key(label, vistas), label: label, route: false, section: true }
    elsif @markdown_sections.include?(indice)
      match = line.match(MARKDOWN_RE)
      label = "#{match[1]} #{match[2].strip}"
      { key: unique_key(label, vistas), label: label, route: false, section: true }
    end
  end

  # Índices de las líneas Markdown que abren sección (ver el encabezado del archivo).
  def markdown_section_lines(lineas)
    encabezados = markdown_headings(lineas)
    titulo = leading_title(lineas, encabezados)
    encabezados.delete(titulo) if titulo
    nivel = encabezados.values.min
    return Set.new if nivel.nil?

    encabezados.select { |_, n| n == nivel }.keys.to_set
  end

  # { índice => nivel } de los encabezados fuera de bloques de código.
  def markdown_headings(lineas)
    en_codigo = false
    lineas.each_with_index.with_object({}) do |(linea, indice), acc|
      en_codigo = !en_codigo if linea.match?(FENCE_RE)
      next if en_codigo || (match = linea.match(MARKDOWN_RE)).nil?

      acc[indice] = match[1].size
    end
  end

  # Un único "# TÍTULO" en la primera línea con texto es el título del prompt.
  def leading_title(lineas, encabezados)
    primera = lineas.index { |l| l.strip.present? }
    return nil unless primera && encabezados[primera] == 1
    return nil if encabezados.values.count(1) > 1

    primera
  end

  # Un rótulo repetido no pisa al primero: se numera, así borrar el segundo [ESTILO]
  # también se ve.
  def unique_key(label, vistas)
    base = self.class.normalize_key(label)
    vistas[base] += 1
    vistas[base] == 1 ? base : "#{base}##{vistas[base]}"
  end

  # Líneas seguidas de la misma pieza van en el mismo tramo.
  def append(chunks, key, label, route, line)
    ultimo = chunks.last
    return ultimo.lines << line if ultimo && ultimo.key == key && !route

    chunks << Chunk.new(key: key, label: label, route: route, lines: [line])
  end
end
