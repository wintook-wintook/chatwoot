# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CÓMO TERMINA UN TURNO QUE TRAJO ENTRENAMIENTO
# ================================================================================
# La entrevista (InterviewService) habla con el modelo y corre las correcciones.
# Esto decide QUÉ SE LE DEVUELVE a la persona con lo que quedó:
#
#   borrador   (fase C) el Entrenamiento a medio armar, con marcas <PENDIENTE:>.
#              Sin correcciones: sus "errores" son preguntas que la persona todavía
#              no contestó, y mandárselos al modelo es invitarlo a inventar.
#   entrega    el Entrenamiento terminado, después de las correcciones:
#                · lo editado a mano que el asistente pisó vuelve (fase B)
#                · si la edición deja sin ejecutar uno que ejecutaba, se conserva
#                  el que había y lo propuesto va aparte (fase A)
#
# Y en los dos: qué cambió de verdad respecto de lo que había en pantalla.
# ================================================================================

class ContactTrackings::Assistant::TurnOutcome
  Result = ContactTrackings::Assistant::InterviewResult

  # building: lo que dijo el cliente sobre si la entrevista sigue abierta (nil = no
  # sabe, por ejemplo al retomar una sesión vieja).
  # said: lo que escribió la persona en la conversación (ver GuessedTags).
  def initialize(account:, current_draft:, manual:, building: nil, said: [])
    @account = account
    @current_draft = current_draft
    @manual = manual
    @building = building
    @said = said
  end

  def editing? = @current_draft.present?

  # Se está CREANDO: no hay nada en pantalla, o lo que hay es un borrador de la
  # entrevista. Editar es sobre un Entrenamiento terminado.
  #
  # ⚠ Primero se deducía solo de las marcas, y falló en la primera entrevista real
  # (15/09/2026): el modelo adivinó las etiquetas —que no admiten marca—, el borrador
  # quedó sin marcas antes de preguntarlas, y el turno siguiente se trató como una
  # EDICIÓN: la respuesta sobre etiquetas se ignoró. Ahora manda el estado que devolvió
  # el turno anterior; las marcas quedan como respaldo cuando el cliente no lo sabe.
  def building?
    return true unless editing?
    return @building unless @building.nil?

    ContactTrackings::Assistant::PendingMarkers.pending?(@current_draft)
  end

  # Parcial si el modelo lo dice ("completo": false) o, si no dijo nada, si todavía
  # tiene marcas. Medido: sin exigirlo, la llave a veces no viene.
  def partial?(reply, draft)
    return false unless building?
    return reply['completo'] == false unless reply['completo'].nil?

    ContactTrackings::Assistant::PendingMarkers.pending?(draft)
  end

  def partial(turn, options)
    turn.draft, = ContactTrackings::Assistant::GuessedTags.strip(turn.draft, said: @said)
    turn.conflict = restore_manual(turn, [])

    Result.new(reply: turn.message, draft: turn.draft, validation: validate(turn.draft), repairs: 0,
               route_mismatches: [], options: options, changes: changes_payload(turn),
               manual_conflict: turn.conflict, building: true)
  end

  # Una modificación que deja sin ejecutar un Entrenamiento que ejecutaba NO lo
  # reemplaza: se devuelve el que había, y lo propuesto aparte para que la persona
  # decida. Al crear no hay nada que conservar, así que se entrega igual, con sus
  # errores a la vista.
  def delivery(turn, validation, repairs, cruces, proposal)
    validation = with_route_findings(validation, cruces)
    turn.conflict = restore_manual(turn, cruces)
    validation = with_route_findings(validate(turn.draft), cruces) if turn.conflict

    base = { reply: turn.message, repairs: repairs, route_mismatches: cruces, proposal: proposal,
             changes: changes_payload(turn), manual_conflict: turn.conflict }

    if editing? && validation[:blocking].any? && validate(@current_draft)[:blocking].empty?
      return Result.new(**base, draft: @current_draft, validation: validate(@current_draft), manual_conflict: nil,
                                rejected_draft: turn.draft, rejected_validation: validation)
    end

    # Entregado: la entrevista terminó, y lo que venga después es editar.
    Result.new(**base, draft: turn.draft, validation: validation, building: false)
  end

  def diff(turn)
    ContactTrackings::Assistant::DraftDiff.new(@current_draft, turn.draft)
  end

  def validate(draft)
    ContactTrackings::Assistant::ValidatorService.new(draft, account: @account).call
  end

  private

  # Si el asistente pisó sin avisar algo que la persona editó a mano, se le devuelve
  # su versión de esa pieza (ver ManualEdits). Los cruces de ruteo de ramas que ya no
  # están como el asistente las dejó dejan de valer.
  def restore_manual(turn, cruces)
    return nil unless editing?

    resuelto = @manual.resolve(turn.draft, turn.declared)
    return nil if resuelto.nil?

    turn.draft = resuelto[:draft]
    vigentes = ContactTrackings::RouteMap.parse(turn.draft).names
    cruces.select! { |c| vigentes.include?(c.route) }
    resuelto[:conflict]
  end

  # Los cruces que quedaron se muestran como un hallazgo más: quien mira la pantalla
  # no tiene por qué saber que hubo dos comprobaciones distintas, y un aviso que vive
  # solo en el log no existe.
  #
  # Van como DEGRADANTES —el Entrenamiento se guarda—: el motor igual va a elegir
  # alguna rama, solo que no la que esa descripción prometía.
  def with_route_findings(validation, cruces)
    return validation if cruces.empty?

    finding = ->(c) { ContactTrackings::Assistant::RepairPrompts.route_finding(c) }
    validation.merge(degrading: validation[:degrading] + cruces.map(&finding))
  end

  # Lo que se le muestra a la persona: el resumen que escribió el modelo y, al lado,
  # lo que cambió DE VERDAD — marcando lo que tocó sin decirlo. Al crear no hay con
  # qué comparar.
  def changes_payload(turn)
    return nil unless editing?

    cambios = diff(turn)
    sin_declarar = cambios.undeclared(turn.declared).map(&:key)

    { summary: turn.summary,
      touched: cambios.changes.map { |c| { key: c.key, kind: c.kind, declared: sin_declarar.exclude?(c.key) } } }
  end
end
