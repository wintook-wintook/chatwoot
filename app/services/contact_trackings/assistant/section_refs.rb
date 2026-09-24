# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REFERENCIAS ENTRE SECCIONES
# ================================================================================
# Pedido del usuario (24/09/2026), con un agente de admisiones de 15 secciones
# numeradas que se citan entre sí: «→ [6] OBJECIONES», «aplica [10] PRECIO»,
# «[8. ASESORÍA]», «→ [SI PIDE HUMANO]». El motor no las procesa: son texto, y el
# modelo las sigue por convención. Funcionan mientras apunten a algo que existe; al
# renumerar, renombrar o mover una sección se rompen en silencio.
#
#   R1 [N] sin sección N                         «[16]» y no hay [16. …]
#   R2 [N] PARTE que no está dentro de N         «[10] AVANCE» y [10] no tiene ninguna
#                                                subsección ni renglón «AVANCE…»
#   R3 [N. TÍTULO] con otro título               «[8. ASESORIA]» y la 8 se llama distinto
#   R4 [NOMBRE] de una sección que no existe     «→ [SI PIDE HUMANO]» sin ese rótulo
#
# Ámbar: el agente sigue leyendo; lo que se pierde es a dónde lo mandaba la regla.
# Sin secciones numeradas no revisa números (R1–R3): un «[1]» suelto puede ser otra cosa.
# ================================================================================

module ContactTrackings::Assistant::SectionRefs
  HEADER_RE = /\A[ \t]*\[([^\]\n]+)\][ \t]*\z/
  NUMBERED_RE = /\A(\d{1,2})[.)]\s*(.+)\z/
  # [N] seguido de hasta 5 palabras en MAYÚSCULAS (la parte citada), o [N. TÍTULO].
  NUMBER_REF_RE = %r{\[(\d{1,2})(?:[.)]\s*([^\]]+))?\](?:[ \t]+((?:[A-ZÁÉÍÓÚÑ]{3,}(?:[ \t]*/?[ \t]*)){1,5}))?}
  NAME_REF_RE = %r{\[([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ /]{3,60})\]}
  IGNORED_NAMES = %w[PENDIENTE PENDING].freeze
  MAX_FINDINGS = 15

  module_function

  def check(text, findings:)
    lineas = text.to_s.split("\n", -1)
    mapa = sections(lineas)
    hallazgos = lineas.each_with_index.flat_map do |linea, indice|
      next [] if linea.match?(HEADER_RE) || linea.lstrip.start_with?('@ruta')

      number_refs(linea, indice + 1, mapa) + name_refs(linea, indice + 1, mapa)
    end
    hallazgos.first(MAX_FINDINGS).each { |h| findings.add(:degrading, h[:code], h[:message], line: h[:line], wrote: h[:wrote]) }
  end

  # { numbers: { '6' => { title:, parts: [...] } }, names: [...] }
  def sections(lineas)
    mapa = { numbers: {}, names: [] }
    actual = nil
    lineas.each do |linea|
      rotulo = linea[HEADER_RE, 1]
      next actual = add_header(mapa, actual, rotulo) if rotulo

      etiqueta = linea[/\A\s*[-·•]?\s*([^:\n]{3,60}):/, 1]
      actual[:parts] << etiqueta if actual && etiqueta
    end
    mapa
  end

  # Devuelve la sección numerada vigente: la nueva, o la de antes si el rótulo es una
  # subsección suya.
  def add_header(mapa, actual, rotulo)
    mapa[:names] << key(rotulo)
    m = rotulo.strip.match(NUMBERED_RE)
    if m.nil?
      actual[:parts] << rotulo if actual
      return actual
    end

    mapa[:names] << key(m[2])
    mapa[:numbers][m[1]] = { title: m[2], parts: [] }
  end

  def number_refs(linea, numero, mapa)
    return [] if mapa[:numbers].empty?

    linea.scan(NUMBER_REF_RE).filter_map { |n, titulo, parte| number_ref(n, titulo, parte, numero, mapa[:numbers][n]) }
  end

  def number_ref(num, titulo, parte, numero, seccion)
    return finding(:section_ref_missing, numero, "[#{num}]", number: num) if seccion.nil?
    if titulo && !same?(titulo, seccion[:title])
      return finding(:section_ref_title, numero, "[#{num}. #{titulo}]", number: num, title: seccion[:title])
    end
    return nil if parte.blank? || part_of?(parte, seccion)

    finding(:section_ref_part, numero, "[#{num}] #{parte.strip}", number: num, part: parte.strip, title: seccion[:title])
  end

  # Al principio de la línea es un rótulo con su texto al lado («[ESTILO] Breve.»), no una
  # cita (medido: un borrador escrito así daba cinco avisos falsos).
  def name_refs(linea, numero, mapa)
    linea.sub(/\A\s*\[[^\]]*\]/, '').scan(NAME_REF_RE).flatten.filter_map do |nombre|
      next if IGNORED_NAMES.include?(nombre.strip) || mapa[:names].include?(key(nombre))

      finding(:section_ref_name, numero, "[#{nombre.strip}]", name: nombre.strip)
    end
  end

  # «PRECIO» cita «PRECIO / INICIO ECONÓMICO»; «ASESORÍA» cita el renglón «ASESORÍA sin objeción:».
  def part_of?(parte, seccion)
    buscado = key(parte)
    ([seccion[:title]] + seccion[:parts]).any? do |candidato|
      c = key(candidato)
      c.start_with?(buscado) || buscado.start_with?(c)
    end
  end

  def same?(uno, otro)
    a = key(uno)
    b = key(otro)
    a.start_with?(b) || b.start_with?(a)
  end

  def key(texto)
    I18n.transliterate(texto.to_s).upcase.gsub(/[^A-Z0-9]+/, ' ').squish
  end

  def finding(code, numero, wrote, **args)
    { code: code, line: numero, wrote: wrote,
      message: I18n.t("tracking_assistant.findings.#{code}", locale: ContactTrackings::Assistant::Language.resolve,
                                                             line: numero, wrote: wrote, **args) }
  end
end
