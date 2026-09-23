# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUE NADA DEL ENCARGO SE PIERDA (F4 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Sin IA. Después de que el Asistente escribe el Entrenamiento desde el encargo, cada
# regla, prohibición, punto de tono y dato a pedir de la ficha se busca en lo escrito
# por sus palabras con contenido (la misma medida que LostRules). Lo que no está se
# AGREGA en su sección; si la sección no existe, se crea.
#
# POR QUÉ CÓDIGO Y NO PEDIRLE MÁS AL MODELO: medido el 23/09 con el gimnasio, la
# redacción de una sola vez sigue su molde de secciones ([ROL] [ESTILO] [PROHIBIDO]…)
# y soltó "una sola pregunta por mensaje", "máximo 3 renglones", los datos a pedir y
# la decisión de la persona sobre el precio, aun con un "NADA SE PIERDE" en mayúsculas.
#
# También limpia lo que la redacción deja y no es del agente: los rótulos "═══ ZONA …"
# de sus instrucciones y una sección [PENDIENTE] (los pendientes van en el mensaje).
#
# Una regla que la persona descartó al decidir una contradicción no se agrega.
# ================================================================================

class ContactTrackings::Assistant::BriefCoverage
  # categoría de la ficha → [sección donde se agrega, otros nombres que cuentan como ella]
  SECTIONS = {
    'reglas' => ['REGLAS', %w[REGLAS NORMAS]],
    'prohibiciones' => ['PROHIBIDO', %w[PROHIBIDO PROHIBICIONES NUNCA]],
    'tono' => ['ESTILO', %w[ESTILO TONO]],
    'datos_a_pedir' => ['DATOS A PEDIR', ['DATOS A PEDIR', 'DATOS']]
  }.freeze
  LINE_COVERAGE = 0.6
  MIN_WORD_CHARS = 4
  ASSISTANT_RULER = /\A\s*═{3}.*═{3}\s*\z/
  PENDING_SECTION = /\A\s*\[\s*PENDIENTES?:?\s*\]\s*\z/i
  SECTION_RE = ContactTrackings::Assistant::DraftPieces::SECTION_RE

  def initialize(draft, ficha:, answers: {})
    @draft = draft.to_s
    @ficha = ficha || {}
    @discarded = ContactTrackings::Assistant::BriefComposer.discarded(@ficha, answers)
  end

  # { draft:, added: [{ 'section' => 'REGLAS', 'text' => '…' }] }
  def call
    lineas = clean(@draft.split("\n", -1))
    agregados = missing(lineas.join("\n"))
    agregados.group_by { |a| a['section'] }.each { |seccion, puntos| insert(lineas, seccion, puntos.pluck('text')) }
    { draft: lineas.join("\n"), added: agregados }
  end

  private

  # Sin los rótulos de instrucciones ni la sección [PENDIENTE] (con su contenido).
  def clean(lineas)
    dentro_de_pendiente = false
    lineas.reject do |linea|
      dentro_de_pendiente = true if linea.match?(PENDING_SECTION)
      dentro_de_pendiente = false if dentro_de_pendiente && linea.match?(SECTION_RE) && !linea.match?(PENDING_SECTION)
      dentro_de_pendiente || linea.match?(ASSISTANT_RULER)
    end
  end

  def missing(texto)
    lineas = texto.split("\n").map { |l| words(l) }
    todo = words(texto)
    SECTIONS.flat_map do |campo, (seccion, _)|
      Array(@ficha[campo]).filter_map do |punto|
        frase = punto['texto'].to_s.strip
        next if frase.blank? || @discarded.include?(frase) || covered?(words(frase), lineas, todo)

        { 'section' => seccion, 'text' => frase }
      end
    end
  end

  # Una frase de una o dos palabras ("nombre", "teléfono") está si aparecen todas;
  # una más larga, si alguna línea tiene al menos LINE_COVERAGE de sus palabras.
  def covered?(palabras, lineas, todo)
    return true if palabras.empty?
    return (palabras - todo).empty? if palabras.size <= 2

    lineas.any? { |otras| (palabras & otras).size.fdiv(palabras.size) >= LINE_COVERAGE }
  end

  def words(texto)
    texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase
         .scan(/[a-z0-9]+/).select { |w| w.size >= MIN_WORD_CHARS }.uniq
  end

  # Al final de la sección si existe (antes de los renglones en blanco que la cierran);
  # si no, una sección nueva al final del Entrenamiento.
  def insert(lineas, seccion, textos)
    nuevas = textos.map { |t| "- #{t}" }
    inicio = section_index(lineas, seccion)
    return append_section(lineas, seccion, nuevas) if inicio.nil?

    fin = ((inicio + 1)...lineas.size).find { |n| lineas[n].match?(SECTION_RE) } || lineas.size
    fin -= 1 while fin > inicio + 1 && lineas[fin - 1].strip.empty?
    lineas.insert(fin, *nuevas)
  end

  def section_index(lineas, seccion)
    nombres = SECTIONS.values.find { |nombre, _| nombre == seccion }.last.map { |n| key(n) }
    lineas.index { |l| (rotulo = l[SECTION_RE, 1]) && nombres.include?(key(rotulo)) }
  end

  def append_section(lineas, seccion, nuevas)
    lineas.pop while lineas.last&.strip&.empty?
    lineas.push('', "[#{seccion}]", *nuevas)
  end

  def key(texto)
    I18n.transliterate(texto.to_s).upcase.squish
  end
end
