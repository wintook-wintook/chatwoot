# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REGLAS QUE DESAPARECEN EN UNA PROPUESTA
# ================================================================================
# Una optimización puede quitar una regla diciendo que es "redundante". Esto verifica
# esa afirmación sin IA: cada línea que ya no está se busca en la propuesta —en su
# misma sección, o en cualquier otra línea— por sus palabras con contenido. Si lo
# esencial no aparece en ningún lado, la regla se perdió.
#
# Salió de medir el Optimizer sobre el v6.11 (15/09/2026): la propuesta pasó los
# controles de ruteo y de secciones, y había borrado "PROHIBIDO cerrar una respuesta
# #comercial1 describiendo algo que HARIA OTRA PERSONA", "cierra con UNA SOLA
# etiqueta" y los ejemplos que sostienen el corte información/gestión — todo marcado
# como redundante, y ninguna estaba en otro lado.
# ================================================================================

class ContactTrackings::Assistant::LostRules
  # Cuánto de las palabras de la regla tiene que seguir estando.
  SECTION_COVERAGE = 0.75
  LINE_COVERAGE = 0.6
  MIN_WORD_CHARS = 4
  MIN_WORDS = 3

  def initialize(before, after)
    @before = before.to_s
    @after = after.to_s
  end

  # [{ section: "[ESTILO]", rule: "la línea tal cual" }]
  def call
    despues = lines_by_section(@after)
    iguales = despues.values.flatten.to_set(&:squish)

    lines_by_section(@before).flat_map do |seccion, lineas|
      lineas.filter_map do |linea|
        next if iguales.include?(linea.squish)

        palabras = words(linea)
        next if palabras.size < MIN_WORDS || covered?(palabras, despues, seccion)

        { section: seccion, rule: linea.strip }
      end
    end
  end

  private

  def covered?(palabras, despues, seccion)
    return true if coverage(palabras, words(Array(despues[seccion]).join(' '))) >= SECTION_COVERAGE

    despues.values.flatten.any? { |linea| coverage(palabras, words(linea)) >= LINE_COVERAGE }
  end

  def coverage(palabras, otras)
    (palabras & otras).size.fdiv(palabras.size)
  end

  def words(texto)
    texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase
         .scan(/[a-z0-9#]+/).select { |w| w.size >= MIN_WORD_CHARS }.uniq
  end

  # Solo las líneas de prosa: las @ruta y los rótulos los cuida DraftDiff.
  def lines_by_section(texto)
    seccion = ContactTrackings::Assistant::DraftPieces::PREAMBLE_KEY
    texto.split("\n").each_with_object(Hash.new { |h, k| h[k] = [] }) do |linea, acc|
      if (rotulo = linea[ContactTrackings::Assistant::DraftPieces::SECTION_RE, 1])
        seccion = "[#{rotulo.strip}]"
      elsif linea.strip.present? && !route_line?(linea)
        acc[seccion] << linea
      end
    end
  end

  def route_line?(linea)
    linea.match?(ContactTrackings::RouteMap::LINE_RE) || linea.match?(ContactTrackings::RouteMap::DEFAULT_RE)
  end
end
