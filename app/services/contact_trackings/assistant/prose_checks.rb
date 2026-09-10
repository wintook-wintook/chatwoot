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
  # Directivas de búsqueda sueltas en la prosa: el motor BLANQUEA lo que queda
  # (contact_tracking_response_analyzer_job.rb:545).
  LOOSE_SEARCH_RE = /@buscar_predefinidas\b|@buscar_art[ií]culo\b|@buscar_foro\([^)]*\)|@discourse\b/i
  # Adjunto que escribe el modelo en su respuesta. Mismo patrón que el job.
  ATTACHMENT_RE = /\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/
  # Nombres reservados que ATTACHMENT_RE captura pero que no son adjuntos.
  NOT_ATTACHMENTS = %w[doc hoja consulta].freeze
  # Las seis secciones de la ZONA 2, en el orden del contrato.
  SECTIONS = ['[ROL]', '[ALCANCE POR RAMA]', '[FIDELIDAD]', '[ETIQUETAS]', '[ESTILO]', '[PROHIBIDO]'].freeze

  def initialize(text, map:, findings:)
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

  # ── B3 ──────────────────────────────────────────────────────────────────────
  # El blanqueo alcanza SOLO a la prosa del camino conversacional: se evalúa sobre
  # el texto ya sin líneas @ruta y alimenta generate_and_send_conversational_reply.
  # Un agente con ramas conserva sus ramas. Por eso el mensaje cambia según haya
  # ramas o no: decirle a alguien que su agente "se queda sin nada" cuando sus 5
  # ramas siguen andando quema la única credibilidad que tiene este aviso.
  def check_loose_directive
    match = prose.match(LOOSE_SEARCH_RE)
    return if match.nil?

    findings.add(:blocking, :loose_directive,
                 t('findings.loose_directive', directive: match[0], consequence: blanking_consequence),
                 wrote: match[0])
  end

  def blanking_consequence
    return t('findings.blanking_no_routes') if map.routes.empty?

    t('findings.blanking_with_routes')
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
