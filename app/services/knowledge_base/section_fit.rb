# frozen_string_literal: true

# ================================================================================
# Un item largo dentro del tope de caracteres, quedándose con lo que pregunta el cliente
# ================================================================================
# Cada item recuperado (respuesta predefinida, artículo, Google Doc) le llega al modelo
# con un tope (KnowledgeBaseResponseService::MAX_ITEM_CHARS). Antes se cortaba al final:
# lo que quedara después del carácter 2000 desaparecía, por más que fuera justo lo que
# se preguntó.
#
# 10/11/2026 (cuenta 1128, conv 168): «en qué precio está la titulación de relaciones
# internacionales». La búsqueda trajo bien la ficha de la carrera (similitud 0.64), pero
# la ficha mide ~2,900 caracteres y «Costo de titulación» empieza en el 2,251: el modelo
# nunca vio el precio y contestó «No tengo la información exacta». Pasaba igual en 6 de
# las 7 licenciaturas.
#
# Ahora el texto se parte en bloques (separados por línea en blanco; un encabezado suelto
# como «TITULACIÓN» va con el bloque que sigue). El primer bloque —el nombre del item—
# entra siempre. Después entran los bloques que comparten palabras con la pregunta, los
# que más primero, y con lo que sobre, el resto en su orden. Salen en el orden original,
# con «[…]» donde se saltó algo para que el modelo sepa que el item no está completo.
#
# Las palabras del TÍTULO del item no cuentan: «relaciones internacionales» está en el
# título y en el perfil de egreso, y no dice qué sección de la ficha se busca.
#
# Si ningún bloque coincide (un «¿y cuánto?» sin más), se corta al final como antes.
# ================================================================================

module KnowledgeBase::SectionFit
  GAP = '[…]'
  # Por prefijo: «titulacion» encuentra «titulación» y «titulaciones».
  PREFIX = 6
  MIN_WORD = 4
  STOPWORDS = %w[
    cual cuales como donde cuando cuanto cuanta cuantos cuantas esta estan este esto estos
    para pero porque sobre tiene tienen tengo quiero puedo puede hola gracias favor buenas
    buenos dias tardes noches quisiera saber informacion info mucho poco algun alguna
    ustedes usted ella ellos eres seria podria hacer hace dime decir
  ].freeze
  # Cómo pregunta el cliente vs. cómo está escrito: «¿cuánto cuesta?» → «costo», «precio»;
  # «¿hay otras ofertas?» → «beca» (11/11/2026, Santos 10: sin esto «ofertas» no tocaba
  # ninguna sección); «¿en qué enlace me inscribo?» → «liga», «inscripción».
  SYNONYMS = {
    %w[cuesta cuestan cobran pagar pago pagos precio precios costo costos sale] => %w[precio costo pago],
    %w[oferta ofertas descuento descuentos rebaja rebajas barato barata baratos promocion promociones cupon cupones
       beca becas] => %w[beca descuento cupon],
    %w[enlace enlaces link links liga ligas vinculo vinculos inscribo inscribirme inscribir inscripcion] => %w[liga inscripcion]
  }.freeze

  module_function

  def call(content, query, max, title: nil)
    text = content.to_s
    return text if text.size <= max

    blocks = blocks_of(text)
    scores = scores_for(blocks, words_of(query) - words_of(title))
    return text.truncate(max) if blocks.size < 2 || scores.none?(&:positive?)

    chosen = choose(blocks, scores, max)
    Rails.logger.info "[KBase] ✂️ #{title.to_s.truncate(40)}: #{chosen.size}/#{blocks.size} bloques por la pregunta"
    render(blocks, chosen)
  end

  # Párrafos; un encabezado de una sola línea se pega al párrafo que lo sigue.
  def blocks_of(text)
    text.split(/\n\s*\n/).map(&:strip).reject(&:empty?).each_with_object([]) do |block, out|
      if out.any? && heading?(out.last)
        out[-1] = "#{out.last}\n\n#{block}"
      else
        out << block
      end
    end
  end

  def heading?(block)
    block.exclude?("\n") && block.size <= 60 && block == block.upcase && block.match?(/\p{L}/)
  end

  # Palabras del texto, sin acentos ni dígitos colados («titulacio0n» → «titulacion»).
  def words_of(text)
    normalized = ActiveSupport::Inflector.transliterate(text.to_s.downcase).gsub(/\d/, '')
    words = normalized.scan(/[a-z]+/).select { |w| w.size >= MIN_WORD } - STOPWORDS
    expanded = words.flat_map { |w| SYNONYMS.find { |keys, _| keys.include?(w) }&.last || [w] }
    expanded.map { |w| w[0, PREFIX] }.uniq
  end

  def scores_for(blocks, stems)
    return Array.new(blocks.size, 0) if stems.empty?

    blocks.map do |block|
      haystack = ActiveSupport::Inflector.transliterate(block.downcase)
      stems.count { |stem| haystack.include?(stem) }
    end
  end

  # Índices que entran: el primero, luego los que coinciden (más coincidencias antes) y
  # al final el resto en orden, cada uno solo si cabe completo.
  def choose(blocks, scores, max)
    order = [0] +
            (1...blocks.size).select { |i| scores[i].positive? }.sort_by { |i| [-scores[i], i] } +
            (1...blocks.size).reject { |i| scores[i].positive? }
    budget = max
    order.each_with_object([]) do |i, chosen|
      cost = blocks[i].size + 2 + GAP.size + 2
      next if cost > budget

      chosen << i
      budget -= cost
    end.sort
  end

  def render(blocks, chosen)
    parts = []
    blocks.each_index do |i|
      if chosen.include?(i)
        parts << blocks[i]
      elsif parts.last != GAP
        parts << GAP
      end
    end
    parts.join("\n\n")
  end
end
