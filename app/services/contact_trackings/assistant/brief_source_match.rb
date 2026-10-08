# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ¿EL CONOCIMIENTO YA ESTÁ EN UNA FUENTE? (M4 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Con ADAM (29/09/2026) la redacción puso @buscar_articulo en las 52 rutas: el encargo
# nunca dice que su conocimiento está publicado en Foro_Sentidos_Creativos. Y la lectura
# pagó por resumir ese conocimiento (servicios, R.A.D.A.R., Kontrolya…) que ya estaba ahí.
#
# Sin IA: los títulos «##» del encargo se buscan en cada foro de la cuenta. Un título está
# en el foro si algún tema que devuelve la búsqueda comparte la mayoría de sus palabras.
#
#   títulos del encargo ─► buscar en cada foro ─► [{ directiva, cubiertos/total, secciones }]
#
# La persona confirma en el modal (decisión D2). Si un foro cubre MIN_COVERAGE o más, la
# lectura no paga el «texto oficial» de esas secciones (BriefDigestService#in_source?).
# Solo foros por ahora: son los que se pueden buscar por título sin bajar todo.
# ================================================================================

class ContactTrackings::Assistant::BriefSourceMatch
  MIN_COVERAGE = 0.5
  MAX_TITLES = 100
  PARALLEL = 4
  MIN_WORD = 4
  TITLE_RE = /\A\#{2}\s+(?<titulo>.+?)\s*\z/
  # Secciones que son la forma del documento, no un tema.
  IGNORED = /\A(norma|texto oficial|introducci[oó]n|[ií]ndice|glosario)\b/i

  def self.best(sugerencias)
    Array(sugerencias).find { |s| s['total'].to_i.positive? && s['cubiertos'].to_f / s['total'] >= MIN_COVERAGE }
  end

  # «Desarrollo Web® — Cómo se presenta» y «desarrollo web» son el mismo título.
  def self.key(titulo)
    I18n.transliterate(titulo.to_s.split(/\s[—–-]\s/).first.to_s.delete('®')).downcase.squish
  end

  def initialize(account, text:)
    @account = account
    @text = text.to_s
  end

  # [{ 'directiva', 'nombre', 'tipo', 'cubiertos', 'total', 'secciones' => [claves] }], la mejor primero.
  def call
    titulos = section_titles
    return [] if titulos.empty?

    forums.map { |fuente| coverage(fuente, titulos) }.sort_by { |s| -s['cubiertos'] }
  end

  private

  def section_titles
    @text.each_line.filter_map { |l| l.strip.match(TITLE_RE)&.[](:titulo) }
         .map { |t| self.class.key(t) }.reject { |t| t.blank? || t.match?(IGNORED) }.uniq.first(MAX_TITLES)
  end

  def forums
    @account.knowledge_sources.where(source_type: 'discourse', status: 'active').to_a
  end

  def coverage(fuente, titulos)
    buscador = KnowledgeBase::DiscourseKeywordSearch.new(fuente.config, ask: ->(_m) {})
    cola = Queue.new
    titulos.each { |t| cola << t }
    cubiertos = Array.new(PARALLEL) { Thread.new { covered_titles(buscador, cola) } }.flat_map(&:value)
    { 'directiva' => "@buscar_foro(#{fuente.name})", 'nombre' => fuente.name, 'tipo' => 'discourse',
      'cubiertos' => cubiertos.size, 'total' => titulos.size, 'secciones' => titulos & cubiertos }
  end

  def covered_titles(buscador, cola)
    encontrados = []
    while (titulo = pop(cola))
      encontrados << titulo if buscador.find(titulo).any? { |hit| same_topic?(titulo, hit[:title]) }
    end
    encontrados
  end

  def pop(cola)
    cola.pop(true)
  rescue ThreadError
    nil
  end

  # La mayoría de las palabras con contenido del título están en el título del tema del foro.
  def same_topic?(titulo, tema)
    palabras = words(titulo)
    return false if palabras.empty?

    (palabras & words(self.class.key(tema))).size.fdiv(palabras.size) >= 0.5
  end

  def words(texto) = texto.scan(/[a-z0-9]+/).select { |w| w.size >= MIN_WORD || w.match?(/\d/) }
end
