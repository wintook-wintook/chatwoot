# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — COMPROBACIONES SOBRE LA PROSA
# ================================================================================
# Lo que hay que revisar en la ZONA 2 del Entrenamiento: el texto que lee el modelo
# del agente, una vez quitadas las líneas @ruta.
#
# Va aparte del comprobador principal porque es la división que el propio contrato
# hace: la ZONA 1 son líneas que parsea el sistema y la ZONA 2 es prosa. Las reglas
# de cada zona miran cosas distintas —una, sintaxis exacta; la otra, qué sobra o
# falta en un texto libre— y se leen mejor separadas.
#
# Escribe en el mismo colector de hallazgos: para quien consume el resultado no hay
# dos comprobadores, hay uno.
# ================================================================================

class ContactTrackings::Assistant::ProseChecks
  # Directivas de búsqueda sueltas en la prosa. El motor ya NO blanquea el prompt
  # por esto: develop lo corrigió el 11/09/2026 (strip_tokens quita solo el token
  # y conserva la prosa alrededor). Sigue siendo un defecto —la directiva no se
  # ejecuta desde ahí— pero dejó de ser catastrófico, así que bajó de bloqueante a
  # degradante.
  # Con {{doc:}} y {{hoja:}} desde el 24/09/2026: un agente de admisiones las nombraba 9
  # veces en la prosa («ejecuta {{hoja:CATALOGO DE CARRERAS}}») y nada lo marcaba.
  LOOSE_SEARCH_RE = /@buscar_predefinidas\b|@buscar_art[ií]culo\b|@buscar_foro\([^)]*\)|@discourse\b|\{\{\s*(?:doc|hoja)\s*:[^}]*\}\}/i
  # Adjunto que escribe el modelo en su respuesta. Mismo patrón que el job.
  ATTACHMENT_RE = /\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/
  # Nombres reservados que ATTACHMENT_RE captura pero que no son adjuntos.
  NOT_ATTACHMENTS = %w[doc hoja consulta].freeze
  # Las seis secciones de la ZONA 2, en el orden del contrato.
  SECTIONS = ['[ROL]', '[ALCANCE POR RAMA]', '[FIDELIDAD]', '[ETIQUETAS]', '[ESTILO]', '[PROHIBIDO]'].freeze

  def initialize(text, map:, findings:)
    @text = text.to_s
    @prose = ContactTrackings::RouteMap.strip(text)
    @map = map
    @findings = findings
  end

  def call
    check_loose_directive
    check_attachment_with_source
    check_sections
  end

  private

  attr_reader :prose, :map, :findings

  # Mensajes en config/locales/tracking_assistant.*.yml — ver Assistant::Language.
  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end

  # ── D7 · directiva suelta en la prosa (era B3, bloqueante) ──────────────────
  # HASTA EL 11/09/2026 ESTO BLANQUEABA EL PROMPT ENTERO, y este aviso era
  # bloqueante porque el agente se quedaba literalmente sin instrucciones.
  # develop lo corrigió: `KnowledgeBase::Directives.strip_tokens` quita solo el
  # token de la directiva y conserva la prosa de alrededor, así que una regla que
  # apenas NOMBRA una directiva ya no cuesta el Entrenamiento completo.
  #
  # El aviso se queda, pero como DEGRADANTE: la directiva sigue sin ejecutarse
  # desde la prosa —solo corre dentro de una línea @ruta— y quien la escribió ahí
  # probablemente creía que sí. Lo que ya no corresponde es impedir el guardado
  # por algo que el motor resuelve solo.
  #
  # ⚠ Si este aviso vuelve a decir "blanquea", está mintiendo: el comportamiento
  # se verifica en Directives.strip_tokens, no acá.
  #
  # Una por línea, con su número (24/09/2026): el editor pinta cada una y el aviso
  # muestra la línea TAL COMO LE LLEGA AL AGENTE, que es lo que se entiende de verdad.
  # Antes decía «si era solo una mención, se puede dejar», y una regla de evidencia
  # entera («Solo @buscar_predefinidas autoriza…») le llegaba al agente sin sujeto.
  MAX_LOOSE_LINES = 20

  def check_loose_directive
    loose_lines.first(MAX_LOOSE_LINES).each do |numero, linea|
      directiva = linea[LOOSE_SEARCH_RE]
      findings.add(:degrading, :loose_directive,
                   t('findings.loose_directive', directive: directiva, line: numero,
                                                 as_read: KnowledgeBase::Directives.strip_tokens(linea).squish.truncate(160)),
                   wrote: directiva, line: numero)
    end
  end

  # [[número, línea]] de la prosa (sin las líneas @ruta) que nombran una directiva.
  def loose_lines
    @text.split("\n", -1).each_with_index.filter_map do |linea, indice|
      next if linea.lstrip.start_with?('@ruta')

      [indice + 1, linea] if linea.match?(LOOSE_SEARCH_RE)
    end
  end

  # ── D6 ──────────────────────────────────────────────────────────────────────
  def check_attachment_with_source
    return if map.routes.none? { |route| route.directive.present? }

    nombres = prose.scan(ATTACHMENT_RE).flatten.uniq - NOT_ATTACHMENTS
    return if nombres.empty?

    findings.add(:degrading, :attachment_with_source,
                 t('findings.attachment_with_source', name: nombres.first),
                 wrote: "{{#{nombres.first}}}")
  end

  # ── C1 ──────────────────────────────────────────────────────────────────────
  def check_sections
    faltan = SECTIONS.reject { |section| prose.include?(section) }
    return if faltan.empty?
    # Sin ninguna sección no es que "falten": es que la prosa no sigue el formato.
    return if faltan.size == SECTIONS.size

    findings.add(:cosmetic, :missing_prose_sections, t('findings.missing_prose_sections', sections: faltan.join(' ')))
  end
end
