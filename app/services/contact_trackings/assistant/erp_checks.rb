# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — EL COMPROBADOR DE {{consulta:}} (docs/erp_productos_plan.md F3)
# ================================================================================
# Lo que el motor hace con una {{consulta:}} y que el Entrenamiento puede romper sin que
# nadie se entere (el motor es fail-soft: una consulta que no existe devuelve vacío):
#
#   D4  (degrada)  una {{consulta:}} SIN "?" que no es fuente de una ruta, con más texto
#                  alrededor: el motor manda el Entrenamiento entero interpolado como
#                  mensaje. Antes de la F2 avisaba siempre; ahora no avisa si la consulta
#                  pide "?" (el agente redacta) ni si es la fuente de una ruta (el motor
#                  usa solo esa directiva).
#   B9  (bloquea)  la consulta no existe (o está inactiva) en la conexión.
#   B10 (bloquea)  un parámetro que la consulta no tiene: "pecio_max=?" nunca se llena.
#
# La conexión se busca con las MISMAS reglas que el motor (ConsultaDirectiveRenderer#
# resolve); sin prefijo, la del bot de cobranza global de la cuenta (el comprobador no
# conoce el inbox).
# ================================================================================
class ContactTrackings::Assistant::ErpChecks
  def initialize(text, map:, account:, findings:)
    @text = text
    @map = map
    @account = account
    @findings = findings
  end

  def call
    return unless ExternalDb::ConsultaDirectiveRenderer.contains?(@text)

    check_isolation
    directives.each { |directive| check_directive(directive) }
  end

  private

  attr_reader :findings

  def directives
    @directives ||= ExternalDb::ConsultaDirectiveRenderer.parse(@text)
  end

  def route_sources
    @route_sources ||= @map.routes.map(&:directive).join("\n")
  end

  # Solo las que el motor interpola dentro del Entrenamiento: sin "?" y fuera de una ruta.
  def check_isolation
    loose = directives.reject { |d| d.asks? || route_sources.include?(d.raw) }
    return if loose.empty?

    rest = ContactTrackings::RouteMap.strip(@text).gsub(ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE, '').strip
    return if @map.routes.empty? && rest.blank?

    findings.add(:degrading, :erp_directive_not_isolated, t('findings.erp_directive_not_isolated'), wrote: loose.first.raw)
  end

  def check_directive(directive)
    query = renderer.resolve(directive)
    return consulta_not_found(directive) if query.nil?

    known = Array(query.params_schema).map { |p| (p['key'] || p[:key]).to_s }
    unknown = (directive.fixed.keys + directive.asked) - known
    return if unknown.empty?

    findings.add(:blocking, :consulta_unknown_param,
                 t('findings.consulta_unknown_param', name: directive.name, params: unknown.join(', '),
                                                      available: known.join(', ')),
                 wrote: directive.raw)
  end

  def consulta_not_found(directive)
    findings.add(:blocking, :consulta_not_found,
                 t('findings.consulta_not_found', name: directive.name, connection: directive.conn || '—'),
                 wrote: directive.raw)
  end

  def renderer
    @renderer ||= ExternalDb::ConsultaDirectiveRenderer.new(account: @account)
  end

  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
