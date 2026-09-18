# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — F6: ¿ESTE TURNO ABRIRÍA UN CASO?
# ================================================================================
# Parte de la prueba en seco (DryRunService). Va en su propio archivo porque no es
# una consulta: es un ESPEJO de la decisión que toma
# ContactTrackingResponseAnalyzerJob#process, y esa decisión tiene tres caminos que
# conviene poder leer —y probar— sin el resto del informe alrededor.
#
#   ¿alguna rama declara escalamiento (->)?
#     sí, y ESTA rama lo declara  → el caso se evalúa DESPUÉS de la fuente
#     sí, pero esta rama NO       → se cae a la directiva global del prompt, y se
#                                   evalúa ANTES de la fuente
#     no                          → rige la global; el orden lo decide fallback=true
#
# El del medio es el que sorprende, y es el que esto existe para hacer visible: una
# rama sin flecha, en un agente donde otras sí la tienen, NO queda sin escalamiento.
# Hereda el @crear_ticket suelto del prompt (TicketCreatorService#directive_source
# cae al complementary_prompt entero cuando no le pasan directiva) y encima se
# adelanta a la fuente, porque `ticket_as_fallback` queda en false.
#
# Lo que informa es "abriría", no "abre": aun con la directiva puesta, el intake
# todavía puede decidir que la conversación no amerita caso (not_worthy).
# ================================================================================

class ContactTrackings::Assistant::CaseForecast
  def initialize(account, draft:, map:, route:)
    @account = account
    @draft   = draft.to_s
    @map     = map
    @route   = route
  end

  def call
    return { creates: false, inherited_from_prompt: inherited? } unless ticket_directive?(directive_text)

    {
      creates: true,
      directive: own? ? @route.escalation : global_directive,
      case_type: case_type,
      inherited_from_prompt: inherited?,
      after_source: after_source?
    }
  end

  private

  # ¿Alguna rama declara escalamiento propio? Si ninguna lo hace, no hay escalamiento
  # por rama y rige la directiva global del prompt.
  def by_branch?
    return @by_branch if defined?(@by_branch)

    @by_branch = @map.routes.any? && @map.escalations?
  end

  # ¿ESTA rama declara el suyo?
  def own?
    return @own if defined?(@own)

    @own = by_branch? && @route.present? && @route.escalates?
  end

  def inherited?
    by_branch? && !own?
  end

  def directive_text
    own? ? @route.escalation : @draft
  end

  def after_source?
    return own? if by_branch?

    # Sin escalamientos por rama manda @crear_ticket(fallback=true) del prompt.
    Cases::TicketCreatorService.fallback?(ContactTracking.new(complementary_prompt: @draft))
  end

  def ticket_directive?(text)
    text.to_s.match?(Cases::TicketCreatorService::DIRECTIVE_RE)
  end

  def global_directive
    @draft[Cases::TicketCreatorService::DIRECTIVE_RE]
  end

  # El tipo declarado en la directiva (tipo=Soporte), resuelto contra los tipos de la
  # cuenta: un tipo escrito que no existe cae al que infiera el intake, y eso es
  # justo lo que hay que poder ver antes de guardar.
  def case_type
    name = declared_type
    return nil if name.blank?

    { name: name, exists: @account.case_types.exists?(['LOWER(name) = ?', name.downcase]) }
  end

  def declared_type
    params = directive_text.to_s[Cases::TicketCreatorService::DIRECTIVE_RE, 1]
    return nil if params.blank?

    params.split(',').filter_map do |pair|
      key, value = pair.split('=', 2).map { |s| s.to_s.strip }
      value if key.to_s.casecmp('tipo').zero? && value.present?
    end.first
  end
end
