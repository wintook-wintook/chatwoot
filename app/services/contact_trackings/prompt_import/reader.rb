# frozen_string_literal: true

# ================================================================================
# proyecto@importar_prompt_md — F0: LEER EL .md
# ================================================================================
# Plan: docs/importar_prompt_md_plan.md (§4.1). Primer paso del importador: convierte el
# .md en bloques y reglas, SIN IA. Todo lo demás (repartir, condensar, proponer rutas)
# trabaja sobre lo que sale de acá.
#
#   blocks   un bloque por título (#…######), con su ruta de títulos y su tamaño
#   rules    las reglas numeradas, si el documento las trae con el formato de ADAM:
#
#     **C7-06.06** (inviolable) — Verifica la autoridad de decisión con una sola pregunta…
#       - Activación:   Cuando falte confirmar quién decide la contratación.
#       - Verificación: El mensaje contiene una única pregunta y no encadena urgencia…
#       - Prompt:       Verifica autoridad de decisión con una sola pregunta por mensaje…
#
#   format   :rules    trae ese formato (desde MIN_RULES reglas): lo demás sale casi solo
#            :generic  un prompt común, escrito a mano: solo bloques, y la IA hace el
#                      resto en los pasos siguientes
#
# Los bloques llevan su ROL cuando el título lo dice: "### Norma" (reglas) y
# "### Texto oficial" (explicación larga, que nunca va al prompt). Los subtítulos lo
# heredan: en ADAM el texto oficial vive en sus "####", no en el "###".
#
# Medido con ADAM-2.0 (1,1 MB, 818 reglas, 3.223 títulos): se lee en menos de un segundo.
# ================================================================================
class ContactTrackings::PromptImport::Reader
  MAX_BYTES = 5.megabytes
  # Menos que esto y "**X-1** (algo) — …" puede ser una casualidad del texto, no un formato.
  MIN_RULES = 3

  HEADING_RE = /\A(?<marks>\#{1,6})[ \t]+(?<title>.+?)[ \t]*#*[ \t]*\z/
  FENCE_RE   = /\A[ \t]*(```|~~~)/
  RULER_RE   = /\A[-*_]{3,}\z/
  RULE_RE    = /\A\*\*(?<id>[A-Z][A-Z0-9]*-\d+(?:\.\d+)*)\*\*[ \t]*\((?<severity>[^)]+)\)[ \t]*[—–-][ \t]*(?<text>.+)\z/
  FIELD_RE   = /\A[ \t]+[-*][ \t]+(?<key>[^:]{1,40}):[ \t]*(?<value>.*)\z/

  # Clave del campo, ya sin tildes ni mayúsculas → atributo de la regla.
  FIELDS = { 'activacion' => :activation, 'verificacion' => :verification, 'prompt' => :prompt }.freeze
  SEVERITIES = %w[inviolable obligatoria recomendada].freeze
  ROLES = { 'norma' => :norm, 'texto oficial' => :official_text }.freeze

  # excerpt: el primer párrafo del bloque (sin sus subtítulos), para que el reparto pueda
  # juzgarlo sin leer el documento entero.
  EXCERPT_CHARS = 300
  Block = Struct.new(:index, :level, :title, :path, :role, :line, :chars, :excerpt, keyword_init: true)
  Rule = Struct.new(:id, :severity, :text, :activation, :verification, :prompt, :path, :role, :line,
                    keyword_init: true)
  Result = Struct.new(:format, :blocks, :rules, :stats, :error, keyword_init: true) do
    def ok?
      error.nil?
    end
  end

  def self.call(markdown)
    new(markdown).call
  end

  def initialize(markdown)
    @raw = markdown.to_s
  end

  def call
    return Result.new(error: :too_large, blocks: [], rules: [], stats: {}) if @raw.bytesize > MAX_BYTES

    text = normalize(@raw)
    return Result.new(error: :empty, blocks: [], rules: [], stats: {}) if text.strip.empty?

    @lines = text.split("\n")
    walk
    Result.new(format: @rules.size >= MIN_RULES ? :rules : :generic, blocks: @blocks, rules: @rules,
               stats: stats)
  end

  private

  # UTF-8 válido, sin BOM y con saltos de línea de Unix: un .md exportado de Word o de
  # Windows no puede leerse distinto.
  def normalize(raw)
    raw.dup.force_encoding(Encoding::UTF_8).scrub('').delete_prefix("\uFEFF").gsub(/\r\n?/, "\n")
  end

  def walk
    @blocks = []
    @rules  = []
    @stack  = [] # los títulos abiertos, del más general al actual
    @fenced = false
    @rule   = nil
    @lines.each_with_index { |line, number| read(line, number) }
  end

  def read(line, number)
    heading = !@fenced && line.match(HEADING_RE)
    return open_block(heading, number) if heading

    count(line)
    if line.match?(FENCE_RE)
      @fenced = !@fenced
    elsif !@fenced
      read_body(line, number)
    end
  end

  def read_body(line, number)
    remember_excerpt(line)
    if (found = line.match(RULE_RE))
      @rule = add_rule(found, number)
    elsif @rule && (field = line.match(FIELD_RE))
      add_field(field)
    elsif line.strip.present? && !line.start_with?(' ', "\t")
      @rule = nil
    end
  end

  # Solo el primer párrafo: termina en la primera línea en blanco que venga después de texto,
  # o al llegar a EXCERPT_CHARS. Un excerpt congelado ya no crece.
  def remember_excerpt(line)
    excerpt = open_excerpt
    text = line.strip
    return if excerpt.nil?
    return excerpt.freeze if text.empty? && excerpt.present?
    return if text.empty? || text.match?(RULER_RE)

    append_excerpt(excerpt, text)
  end

  def append_excerpt(excerpt, text)
    excerpt << (excerpt.empty? ? text : " #{text}")
    excerpt.replace(excerpt.truncate(EXCERPT_CHARS)).freeze if excerpt.size >= EXCERPT_CHARS
  end

  def open_excerpt
    excerpt = @blocks.last&.excerpt
    excerpt unless excerpt.nil? || excerpt.frozen?
  end

  def open_block(heading, number)
    @rule = nil
    level = heading[:marks].size
    title = heading[:title].strip
    @stack = @stack.take_while { |b| b.level < level }
    block = Block.new(index: @blocks.size, level: level, title: title, path: @stack.map(&:title) + [title],
                      role: ROLES[key_for(title)] || @stack.last&.role, line: number + 1, chars: 0,
                      excerpt: +'')
    @blocks << block
    @stack << block
  end

  # El texto de cada línea cuenta para el bloque abierto (sin sus subtítulos).
  def count(line)
    @blocks.last.chars += line.size + 1 if @blocks.any?
  end

  def add_rule(found, number)
    severity = key_for(found[:severity])
    rule = Rule.new(id: found[:id], severity: SEVERITIES.include?(severity) ? severity : 'otra',
                    text: found[:text].strip, path: @stack.map(&:title), role: @stack.last&.role,
                    line: number + 1)
    @rules << rule
    rule
  end

  def add_field(field)
    attribute = FIELDS[key_for(field[:key])]
    @rule[attribute] = field[:value].strip if attribute
  end

  def key_for(text)
    I18n.transliterate(text.to_s).downcase.squish
  end

  def stats
    {
      bytes: @raw.bytesize,
      lines: @lines.size,
      words: @lines.sum { |l| l.split.size },
      headings: @blocks.size,
      chapters: chapters,
      rules: @rules.size,
      rules_by_severity: @rules.map(&:severity).tally,
      rules_without_prompt: @rules.count { |r| r.prompt.blank? },
      prompt_chars: @rules.sum { |r| r.prompt.to_s.size },
      chars_by_role: chars_by_role
    }
  end

  def chars_by_role
    @blocks.select(&:role).group_by(&:role).transform_values { |bs| bs.sum(&:chars) }
  end

  # Capítulos = los títulos del nivel más alto que aparece más de una vez (en ADAM, los
  # "# C0 · CONSTITUCIÓN"…; el primer "#" es la portada y queda con sus pocas líneas).
  def chapters
    top = @blocks.map(&:level).min
    @blocks.slice_before { |b| b.level == top }.filter_map do |group|
      next unless group.first.level == top

      title = group.first.title
      { title: title, chars: group.sum(&:chars), rules: @rules.count { |r| r.path.first == title } }
    end
  end
end
