# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — TROCEAR UN ENCARGO POR TEMAS (F1 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Parte el .md en trozos de hasta MAX_CHARS para que la IA lea cada uno por separado
# (F2). Sin IA: es texto y reglas.
#
# POR QUÉ POR TEMAS Y NO CADA N CARACTERES:
#   Un trozo cortado a la mitad de una sección le deja a la IA una regla sin su título
#   ("Nunca más de 3." — ¿de qué?). Se corta donde el propio encargo cambia de tema.
#
# CÓMO SE RECONOCE UN TEMA (de más a menos marcado; se usa el más marcado que haya):
#   # Título … ###### Título   Markdown, cada nivel por separado
#   [ROL]                      corchetes, como los Entrenamientos de la cuenta (DraftPieces)
#   === OBJETIVO ===           decorados con = * ~ # _ - a los dos lados
#   PROHIBICIONES              renglón corto en MAYÚSCULAS, suelto (con renglón en blanco antes)
#   (nada)                     por párrafos
#   Un título que aparece UNA vez y en el primer renglón es el nombre del documento, no un
#   tema: "# PROMPT AGENTE DCI V8.12" arriba de todo no parte nada.
#   Los títulos dentro de un bloque de código (```) no cuentan, salvo que el bloque envuelva
#   el documento entero: el Vendedor Escuela (#8533) está todo dentro de un ```text.
#
# EL LÍMITE DEL PLAN ANTERIOR (21/09): el lector solo veía títulos Markdown y reglas con
# formato **ID** (gravedad). ADAM daba 818 reglas; DCI V8.12 daba 1 unidad y los agentes
# reales de la cuenta 2, 0. Por eso esto se prueba con el banco de §2.1 del plan.
#
# NADA SE PIERDE: los trozos son rangos de renglones consecutivos. Pegados con "\n"
# vuelven a dar el texto original, carácter por carácter.
#
# LOS TROZOS CHICOS SE JUNTAN: temas vecinos van en el mismo trozo mientras quepan.
# Un encargo de una página es UN trozo (una sola llamada), y ADAM no se vuelve 3.000.
# ================================================================================

class ContactTrackings::Assistant::BriefChunker
  # Lo que la IA lee de una vez en F2. El mismo número que el presupuesto del Entrenamiento.
  MAX_CHARS = 24_000
  # Un renglón en MAYÚSCULAS más largo que esto es una frase gritada, no un título.
  UPPER_MAX_CHARS = 70
  # Lo que queda antes de un tema demasiado grande (el título del capítulo y su
  # introducción) viaja con el primer trozo de ese tema, en vez de ir solo.
  CARRY_CHARS = 2_000

  MARKDOWN_RE  = /\A(?<marks>\#{1,6})[ \t]+(?<title>.+?)[ \t]*#*[ \t]*\z/
  BRACKET_RE   = ContactTrackings::Assistant::DraftPieces::SECTION_RE
  DECORATED_RE = /\A[ \t]*(?<deco>[=*~#_-])\k<deco>{2,}[ \t]*(?<title>[^=*~#_\n]*?\p{L}[^=*~#_\n]*?)[ \t]*\k<deco>{3,}[ \t]*\z/
  FENCE_RE     = /\A[ \t]*(```|~~~)/
  LIST_RE      = /\A[ \t]*(?:[-*+•]|\d+[.)])[ \t]/

  # Orden de preferencia: la señal más marcada que aparezca es la que corta.
  KINDS = [*(1..6).map { |n| :"h#{n}" }, :bracket, :decorated, :upper].freeze

  Chunk = Struct.new(:index, :path, :titles, :first_line, :last_line, :chars, :sha256, :text, keyword_init: true) do
    # Lo que se guarda en el encargo: el texto se rearma desde el .md con los renglones.
    def to_h
      super.except(:text)
    end
  end
  Heading = Struct.new(:line, :kind, :title, keyword_init: true)
  Section = Struct.new(:title, :from, :to, keyword_init: true)
  Result = Struct.new(:chunks, :outline, :signal, keyword_init: true)

  def self.call(text)
    new(text).call
  end

  def initialize(text)
    @lines = text.to_s.split("\n", -1)
  end

  def call
    @headings = scan
    @chunks = []
    signal, sections = split(0, @lines.size)
    if chars(0, @lines.size) <= MAX_CHARS
      add_chunk([], sections.filter_map(&:title), 0, @lines.size)
    else
      pack(sections, [])
    end
    Result.new(chunks: @chunks, outline: sections.filter_map(&:title), signal: signal)
  end

  private

  # ── reconocer títulos ──────────────────────────────────────────────────────────
  def scan
    fenced = false
    @wrapper = wrapper_fences
    @lines.each_with_index.filter_map do |line, number|
      next if @wrapper.include?(number)

      if line.match?(FENCE_RE)
        fenced = !fenced
        next
      end
      heading_at(line, number) unless fenced
    end
  end

  # Los renglones ``` que abren y cierran el documento entero, si los hay.
  # Uno solo arriba (nunca se cerró), o uno arriba y otro abajo de todo.
  def wrapper_fences
    cercos = @lines.each_index.select { |n| @lines[n].match?(FENCE_RE) }
    con_texto = @lines.each_index.select { |n| @lines[n].strip.present? }
    return [] unless cercos.first == con_texto.first
    return cercos if cercos.one?

    cierra_al_final = cercos.last == con_texto.last && cercos.size.even?
    cierra_al_final ? [cercos.first, cercos.last] : []
  end

  def heading_at(line, number)
    if (found = line.match(MARKDOWN_RE))
      Heading.new(line: number, kind: :"h#{found[:marks].size}", title: found[:title])
    elsif (found = line.match(BRACKET_RE))
      Heading.new(line: number, kind: :bracket, title: found[1].strip)
    elsif (found = line.match(DECORATED_RE))
      Heading.new(line: number, kind: :decorated, title: found[:title].strip)
    elsif upper_title?(line, number)
      Heading.new(line: number, kind: :upper, title: line.strip.delete_suffix(':').strip)
    end
  end

  def upper_title?(line, number)
    texto = line.strip
    return false if texto.length > UPPER_MAX_CHARS || texto.match?(LIST_RE)
    return false if texto.scan(/\p{L}/).size < 3 || texto.match?(/\p{Ll}/)

    number.zero? || @lines[number - 1].strip.empty?
  end

  # ── partir un rango en secciones ───────────────────────────────────────────────
  # [señal usada, secciones]. Sin señal, una sola sección sin título.
  def split(from, to)
    dentro = @headings.select { |h| h.line >= from && h.line < to }
    kind = KINDS.find { |k| divides?(dentro.select { |h| h.kind == k }) }
    return [nil, [Section.new(title: nil, from: from, to: to)]] if kind.nil?

    cortes = dentro.select { |h| h.kind == kind }
    [kind, sections_for(cortes, from, to)]
  end

  # Un título suelto en el primer renglón con texto del documento es su nombre.
  def divides?(headings)
    return false if headings.empty?
    return true if headings.size > 1

    headings.first.line != first_text_line
  end

  def first_text_line
    @first_text_line ||= @lines.each_index.find { |n| @lines[n].strip.present? && @wrapper.exclude?(n) }
  end

  def sections_for(cortes, from, to)
    secciones = []
    secciones << Section.new(title: nil, from: from, to: cortes.first.line) if cortes.first.line > from
    cortes.each_with_index do |corte, i|
      hasta = cortes[i + 1]&.line || to
      secciones << Section.new(title: corte.title, from: corte.line, to: hasta)
    end
    secciones
  end

  # ── armar trozos ───────────────────────────────────────────────────────────────
  def pack(sections, path)
    grupo = []
    sections.each do |seccion|
      next grupo = oversized(seccion, grupo, path) if chars(seccion.from, seccion.to) > MAX_CHARS

      if grupo.any? && chars(grupo.first.from, seccion.to) > MAX_CHARS
        flush(grupo, path)
        grupo = []
      end
      grupo << seccion
    end
    flush(grupo, path)
  end

  # Un tema que no cabe: lo juntado hasta ahí se cierra, o viaja con él si es poco.
  # Devuelve el grupo nuevo (vacío).
  def oversized(seccion, grupo, path)
    arrastre = grupo.first.from if grupo.any? && chars(grupo.first.from, grupo.last.to) <= CARRY_CHARS
    flush(grupo, path) unless arrastre
    chunk_segment_inside(seccion, path, arrastre)
    []
  end

  # Una sección más grande que un trozo: se parte por lo que tenga adentro.
  # `desde`: dónde empieza lo que se arrastra de antes (ver CARRY_CHARS).
  def chunk_segment_inside(section, path, desde = nil)
    ruta = section.title ? path + [section.title] : path
    inicio = section.title ? section.from + 1 : section.from
    kind, subs = split(inicio, section.to)
    return chunk_paragraphs(desde || section.from, section.to, ruta) if kind.nil?

    # El renglón del título (y lo arrastrado) va pegado a lo primero de su sección.
    subs[0] = Section.new(title: subs[0].title, from: desde || section.from, to: subs[0].to)
    pack(subs, ruta)
  end

  def flush(grupo, path)
    return if grupo.empty?

    titulos = grupo.filter_map(&:title)
    # Un solo tema (con o sin la introducción de antes): la ruta llega hasta él.
    ruta = titulos.one? ? path + titulos : path
    add_chunk(ruta, titulos, grupo.first.from, grupo.last.to)
  end

  # Sin títulos: por párrafos (renglón en blanco), sin partir un bloque de código.
  # Un párrafo más largo que un trozo se parte por renglones.
  def chunk_paragraphs(from, to, path)
    desde = from
    paragraphs(from, to).each do |(p_from, p_to)|
      next if chars(desde, p_to) <= MAX_CHARS

      if p_from > desde
        add_chunk(path, [], desde, p_from)
        desde = p_from
      end
      desde = chunk_lines(desde, p_to, path) if chars(desde, p_to) > MAX_CHARS
    end
    add_chunk(path, [], desde, to) if desde < to
  end

  # Devuelve dónde empieza lo que quedó sin trocear.
  def chunk_lines(from, to, path)
    desde = from
    (from...to).each do |n|
      next if chars(desde, n + 1) <= MAX_CHARS || n == desde

      add_chunk(path, [], desde, n)
      desde = n
    end
    desde
  end

  def paragraphs(from, to)
    bloques = []
    inicio = from
    fenced = false
    (from...to).each do |n|
      fenced = !fenced if @lines[n].match?(FENCE_RE)
      next if fenced || @lines[n].strip.present?

      bloques << [inicio, n + 1]
      inicio = n + 1
    end
    bloques << [inicio, to] if inicio < to
    bloques
  end

  def add_chunk(path, titles, from, to)
    texto = @lines[from...to].join("\n")
    @chunks << Chunk.new(index: @chunks.size, path: path, titles: titles, first_line: from + 1, last_line: to,
                         chars: texto.length, sha256: Digest::SHA256.hexdigest(texto), text: texto)
  end

  # Caracteres del rango, contando el salto de línea que los une.
  def chars(from, to)
    return 0 if to <= from

    @lines[from...to].sum { |l| l.length + 1 } - 1
  end
end
