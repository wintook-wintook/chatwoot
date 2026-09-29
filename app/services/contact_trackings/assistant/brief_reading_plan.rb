# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUÉ LEE LA IA DE UN ENCARGO (M1 y M4 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Antes de leer (BriefDigestService), se decide qué parte del encargo necesita IA:
#
#   M1  un reglamento (≥ 20 reglas con id y nivel) → sus reglas salen sin IA
#       (BriefRuleParser) y la IA lee el texto con esos renglones en blanco.
#   M4  si una fuente de la cuenta ya tiene el conocimiento (BriefSourceMatch), el
#       «texto oficial» de esas secciones se reduce a títulos y primer párrafo: alcanza
#       para saber de qué tema es, y no se paga resumir lo que ya está publicado.
#
# Y, al terminar, las reglas numeradas entran a la ficha tal cual, con su nivel.
# ================================================================================

class ContactTrackings::Assistant::BriefReadingPlan
  Chunker = ContactTrackings::Assistant::BriefChunker
  SourceMatch = ContactTrackings::Assistant::BriefSourceMatch
  SUMMARY_NOTE = '(Sección publicada en la fuente de conocimiento: solo títulos y resumen.)'

  attr_reader :numbered, :sources, :chunks

  def initialize(account, content:)
    parsed = ContactTrackings::Assistant::BriefRuleParser.call(content)
    @numbered = parsed.structured? ? parsed : nil
    @sources = SourceMatch.new(account, text: content).call
    @chunks = Chunker.call(@numbered ? @numbered.masked : content).chunks.map { |t| in_source?(t) ? summarized(t) : t }
  end

  def rules_apart? = @numbered.present?

  def summarized_count = @chunks.count { |t| t.text.start_with?(SUMMARY_NOTE) }

  # Las reglas numeradas, tal cual y con su nivel, después de juntar (la IA no las toca) y de
  # buscar contradicciones (un reglamento no se contradice solo, y con 818 reglas
  # BriefContradictions solo vería una muestra).
  def with_numbered_rules(ficha)
    return ficha if @numbered.nil?

    ficha = ficha.deep_dup
    @numbered.rules.each do |regla|
      campo = regla.prohibicion? ? 'prohibiciones' : 'reglas'
      (ficha[campo] ||= []) << regla.to_point(origin: chunk_of(regla.linea))
    end
    ficha
  end

  private

  def chunk_of(linea)
    trozo = @chunks.find { |t| linea.between?(t.first_line, t.last_line) }
    trozo ? [trozo.index] : []
  end

  # Solo en un reglamento (sus reglas ya salieron sin IA): de un encargo común no se
  # adivina qué parte es conocimiento y qué parte es comportamiento.
  def in_source?(trozo)
    mejor = SourceMatch.best(@sources)
    return false if @numbered.nil? || mejor.nil?

    secciones = mejor['secciones'].to_set
    (Array(trozo.path) + Array(trozo.titles)).any? { |t| secciones.include?(SourceMatch.key(t)) }
  end

  def summarized(trozo)
    texto = "#{SUMMARY_NOTE}\n#{titles_and_leads(trozo.text)}"
    copia = trozo.dup
    copia.text = texto
    copia.chars = texto.length
    copia.sha256 = Digest::SHA256.hexdigest(texto)
    copia
  end

  # Los títulos y el primer párrafo debajo de cada uno.
  def titles_and_leads(texto)
    lineas = texto.split("\n")
    lineas.each_with_index.filter_map do |linea, i|
      next linea if linea.start_with?('#')

      linea if linea.strip.present? && lineas[i - 1].to_s.strip.empty? && lineas[i - 2].to_s.start_with?('#')
    end.join("\n")
  end
end
