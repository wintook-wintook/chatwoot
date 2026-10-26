# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO MAL ESCRITO A MANO FUERA DE LAS RUTAS
# ================================================================================
# Pedido del usuario (24/09/2026): el editor de código tiene que avisar de todo lo
# que quede mal al editar a mano, no solo de las @ruta. Medido ese día, pasaban sin
# ningún aviso:
#
#   S1 rótulo de sección roto   «[ROL», «ROL]», «[[ROL]]». Rojo (pedido del usuario,
#                               24/09): el agente lee el rótulo como una instrucción
#                               suelta. El aviso dice qué corchete falta o sobra, y la
#                               sección SIGUE en el árbol, marcada (DraftPieces y
#                               TrainingStructure la leen con broken_header?).
#   S2 rama por defecto rota    «@ruta_por_defecto a» sin «:». El motor no la lee y los
#                               mensajes sin rama no caen en ninguna. Rojo.
#   S3 sección repetida         dos [ROL]: el agente lee dos versiones y el árbol las
#                               muestra como dos. Ámbar.
#   S4 «PENDIENTE:» suelto      una nota de trabajo sin los < > de la marca: el
#                               comprobador no la ve como pendiente y el agente la lee
#                               como una instrucción más. Ámbar.
#
# Todos llevan la línea: el editor la pinta y el árbol cuelga el aviso del bloque.
# ================================================================================

module ContactTrackings::Assistant::StructureChecks
  SECTION_RE = ContactTrackings::Assistant::DraftPieces::SECTION_RE
  # «[ROL» — abre y no cierra. «[ROL]» sí es rótulo, y «[x] hecho» o «[link](url)» son
  # texto: tienen «]».
  OPEN_ONLY_RE = /\A[ \t]*\[[^\]\n]*\z/
  # «ROL]» — cierra sin abrir. Solo en mayúsculas, como se escriben los rótulos: una
  # frase que termina en «]» es texto.
  CLOSE_ONLY_RE = /\A[ \t]*[\p{Lu}\d][\p{Lu}\d _-]*\][ \t]*\z/
  DOUBLE_RE = /\A[ \t]*\[\[[^\]\n]+\]\][ \t]*\z/
  DEFAULT_START_RE = /\A[ \t]*@ruta_por_defecto\b/i
  LOOSE_PENDING_RE = /\A[ \t]*(?:PENDIENTE|PENDING)\s*:/

  module_function

  def check(text, findings:)
    lineas = text.to_s.split("\n", -1)
    lineas.each_with_index do |linea, indice|
      numero = indice + 1
      broken_header(linea, numero, findings)
      broken_default(linea, numero, findings)
      loose_pending(linea, numero, findings)
    end
    duplicate_sections(lineas, findings)
    # R1–R4: las referencias entre secciones («→ [6] OBJECIONES»), ver SectionRefs.
    ContactTrackings::Assistant::SectionRefs.check(text, findings: findings)
  end

  # ¿Quiso ser el rótulo de una sección y está mal escrito?
  def broken_header?(linea)
    return false if linea.match?(SECTION_RE) || linea.lstrip.start_with?('@ruta')

    linea.match?(OPEN_ONLY_RE) || linea.match?(CLOSE_ONLY_RE) || linea.match?(DOUBLE_RE)
  end

  # El nombre que quiso tener: «[ESTILO» → «ESTILO».
  def broken_header_title(linea)
    linea.to_s.strip.delete('[]').strip
  end

  def header_problem(linea)
    return 'extra_bracket' if linea.match?(DOUBLE_RE)

    linea.match?(OPEN_ONLY_RE) ? 'no_closing_bracket' : 'no_opening_bracket'
  end

  def broken_header(linea, numero, findings)
    return unless broken_header?(linea)

    titulo = broken_header_title(linea)
    findings.add(:blocking, :section_header_broken,
                 t('section_header_broken', line: numero, wrote: linea.strip, title: titulo,
                                            problem: t("section_header_problem.#{header_problem(linea)}")),
                 line: numero, wrote: linea.strip)
  end

  def broken_default(linea, numero, findings)
    return unless linea.match?(DEFAULT_START_RE) && !linea.match?(ContactTrackings::RouteMap::DEFAULT_RE)

    findings.add(:blocking, :default_route_line_broken, t('default_route_line_broken', line: numero),
                 line: numero, wrote: linea.strip)
  end

  def loose_pending(linea, numero, findings)
    return unless linea.match?(LOOSE_PENDING_RE)

    findings.add(:degrading, :loose_pending_note, t('loose_pending_note', line: numero),
                 line: numero, wrote: linea.strip)
  end

  def duplicate_sections(lineas, findings)
    vistas = {}
    lineas.each_with_index do |linea, indice|
      titulo = linea[SECTION_RE, 1]&.strip&.upcase
      next if titulo.nil?

      if vistas.key?(titulo)
        findings.add(:degrading, :duplicate_section,
                     t('duplicate_section', title: titulo, line: indice + 1, first: vistas[titulo]),
                     line: indice + 1, wrote: linea.strip)
      else
        vistas[titulo] = indice + 1
      end
    end
  end

  def t(key, **args)
    I18n.t("tracking_assistant.findings.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
