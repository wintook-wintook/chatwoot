# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — COMPROBACIONES DE CADA LÍNEA @ruta
# ================================================================================
# Parte de ValidatorService, aparte porque aquel ya estaba en su tope de largo (como
# ProseChecks y CorpusChecks). Escribe en el mismo colector de hallazgos: para quien
# consume el resultado sigue habiendo un solo comprobador.
# ================================================================================

class ContactTrackings::Assistant::RouteLineChecks
  def initialize(map, findings:)
    @map = map
    @findings = findings
  end

  def call
    check_unclosed_directives
    check_routes_doing_nothing
    check_calendar_options
    check_service_requests
  end

  private

  attr_reader :map, :findings

  # ── B11 · una directiva de la rama sin cerrar ───────────────────────────────
  # Pedido del usuario (24/09/2026): «@crear_ticket(tipo=Soporte, prioridad=media» sin
  # el «)». El motor no falla: Cases::TicketCreatorService::DIRECTIVE_RE lee solo
  # «@crear_ticket» y abre el caso con el tipo y la prioridad por defecto, en silencio.
  # Lo mismo una fuente sin «)» o sin «}}»: lo de adentro no se lee. Rojo: lo escrito
  # no existe para el motor. Solo en las líneas @ruta: en la prosa, un paréntesis
  # suelto es texto.
  CLOSERS = { '(' => ')', '{{' => '}}' }.freeze

  def check_unclosed_directives
    map.routes.each do |route|
      [route.directive, route.escalation].compact_blank.each do |parte|
        next if pending?(parte)

        abierto = CLOSERS.find { |abre, cierra| parte.scan(abre).size > parte.scan(cierra).size }
        next if abierto.nil?

        findings.add(:blocking, :unclosed_directive,
                     t(parte.match?(/\A@crear_ticket/i) ? 'findings.unclosed_ticket' : 'findings.unclosed_directive',
                       route: route.name, wrote: parte, closer: abierto.last),
                     wrote: parte, route: route.name)
      end
    end
  end

  # ── D9 · rama que no consulta nada ni hace nada si no resuelve ──────────────
  # Pedido del usuario (24/09/2026): «De dónde saca la respuesta» en «No consulta
  # nada» y «Si no resuelve» en «Nada: sigue conversando» es válido y no se avisaba.
  # Esa rama contesta solo con el Entrenamiento: ante algo concreto (precio, horario)
  # el modelo inventa o promete lo que no hace — la 173: «te confirmo en un momento».
  # Ámbar y no rojo: a veces es a propósito (saludo, pedir datos). Con una acción
  # después de la flecha (- -> @agendar_calendar) sí hace algo y no se marca.
  def check_routes_doing_nothing
    map.routes.each do |route|
      next if route.source? || route.escalates?

      findings.add(:degrading, :route_does_nothing, t('findings.route_does_nothing', route: route.name),
                   wrote: "@ruta(#{route.name}...): -", route: route.name)
    end
  end

  # ── @agendar_calendar(…) con una opción que el motor no entiende (pieza 3) ────
  # El motor ignora lo que no conoce y agenda con la duración y el horario de siempre:
  # «horario=noche» no da horarios de noche. Rojo: lo escrito no hace lo que dice.
  def check_calendar_options
    map.routes.each do |route|
      ContactTrackings::CalendarOptions.invalid(route.escalation).each do |clave, valor|
        findings.add(:blocking, :calendar_option_invalid,
                     t('findings.calendar_option_invalid', route: route.name, option: "#{clave}=#{valor}"),
                     wrote: route.escalation, route: route.name)
      end
    end
  end

  # ── @solicitudes (pieza 5, F5) ───────────────────────────────────────────────
  # Rojo: sin @crear_ticket después, cada servicio no tiene dónde guardarse.
  # Ámbar: con agenda pero sin {{hoja_buscar:}}, ningún servicio sabe en qué calendario buscar
  # y todos salen «no tengo ese equipo en el catálogo».
  def check_service_requests
    map.routes.each do |route|
      accion = route.escalation.to_s
      next unless ContactTrackings::ServiceRequests::Turn.route?(accion)

      unless accion.match?(Cases::TicketCreatorService::DIRECTIVE_RE)
        findings.add(:blocking, :solicitudes_without_ticket, t('findings.solicitudes_without_ticket', route: route.name),
                     wrote: accion, route: route.name)
      end
      next unless accion.match?(/@agendar_calendar\b/i) && !accion.match?(ContactTrackings::SheetLookup::DIRECTIVE_RE)

      findings.add(:degrading, :solicitudes_without_lookup, t('findings.solicitudes_without_lookup', route: route.name),
                   wrote: accion, route: route.name)
    end
  end

  def pending?(value) = ContactTrackings::Assistant::PendingMarkers.pending?(value)

  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
