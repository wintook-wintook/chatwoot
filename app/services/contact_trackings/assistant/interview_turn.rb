# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — UN TURNO DE ENTREVISTA, DE PUNTA A PUNTA
# ================================================================================
# Lo que antes hacía AssistantController#interview dentro de la request: correr la
# entrevista, guardar el hilo en la sesión y armar la respuesta para la pantalla.
#
# Salió del controlador porque ahora corre en InterviewJob: editar un Entrenamiento
# largo tarda más que los 15 s de rack-timeout y la request moría con un 500
# (cuenta 568, 30/09/2026: seis ediciones seguidas perdidas). Devuelve el JSON que
# antes renderizaba el controlador, o { error: } si el turno no pudo contestar.
#
# params (claves en texto, como viajan por ActiveJob):
#   messages, draft, delivered_draft, building, one_shot, session_id
#   `delivered_draft` y `building` distinguen "no vino" (clave ausente) de vacío:
#   ver el controlador.
# ================================================================================

class ContactTrackings::Assistant::InterviewTurn
  def initialize(account, user, params, inbox: nil, progress: nil)
    @account = account
    @user = user
    @params = params
    @inbox = inbox
    @progress = progress
  end

  def call
    result = interview_service.call
    return { error: result.error.to_s } unless result.success?

    interview_json(result, record_turn(result))
  end

  private

  def interview_service
    servicio = ContactTrackings::Assistant::InterviewService
               .new(@account, messages: messages, inbox: @inbox,
                              drafts: { current: @params['draft'], delivered: delivered_draft, building: building },
                              one_shot: ActiveModel::Type::Boolean.new.cast(@params['one_shot']))
    @progress ? servicio.with_progress(@progress) : servicio
  end

  def interview_json(result, sesion)
    {
      reply: result.reply,
      draft: result.draft,
      validation: result.validation,
      repairs: result.repairs,
      # Los datos del agente que el asistente propone. La pantalla los precarga
      # editables: un nombre propuesto y equivocado se ve y se corrige; un campo
      # vacío frena a quien acaba de explicar en la conversación lo que ahí va.
      proposal: result.proposal,
      # Las preguntas en forma de lista: la pantalla las muestra como botones, así
      # se contesta con un clic en vez de reescribir el nombre de una etiqueta.
      options: result.options,
      # Al editar: lo que dice el modelo que cambió, y lo que cambió de verdad.
      changes: result.changes,
      # Una edición que dejaba sin ejecutar un Entrenamiento que ejecutaba: `draft`
      # sigue siendo el de antes, y esto es lo propuesto, para decidir a la vista.
      rejected_draft: result.rejected_draft,
      rejected_validation: result.rejected_validation,
      # El asistente pisó algo editado a mano: `draft` ya trae la versión de la
      # persona en esas piezas, y esto trae la del asistente para elegirla.
      manual_conflict: result.manual_conflict,
      # true: la entrevista sigue y `draft` es un borrador; false: se entregó; nil:
      # este turno no trajo Entrenamiento y el estado no cambia.
      building: result.building,
      session_id: sesion&.id,
      # Las versiones del Entrenamiento en esta conversación, sin su texto.
      versions: sesion&.version_list,
      # La identidad completa y no solo el id: con el id suelto, la pantalla
      # tendría que inventar las fechas del lado del cliente.
      session: sesion && session_identity(sesion)
    }
  end

  def session_identity(sesion)
    ContactTrackings::Assistant::SessionPresenter.full(sesion, @user)
                                                 .except(:messages, :draft, :validation, :proposal, :versions)
  end

  # El hilo se guarda después de contestar, no antes: si la llamada al modelo falla
  # no queda una sesión a medias que la pantalla ofrezca retomar sin contenido.
  def record_turn(result)
    sesion = session_record || TrackingAssistantSession.new(account: @account, user: @user)
    turnos = with_stored_changes(sesion, messages) + [assistant_turn(result)]
    ContactTrackings::Assistant::SessionVersions.new(sesion, on_screen: @params['draft'], delivered: delivered_draft)
                                                .record(result)
    # Sin Entrenamiento nuevo (una pregunta, un análisis) queda el que estaba en pantalla:
    # si no, la conversación se reabría con el editor vacío (25/09/2026).
    sesion.record_turn(messages: turnos, draft: result.draft.presence || @params['draft'],
                       validation: result.validation, proposal: result.proposal)
    sesion
  rescue StandardError => e
    # Que no se pueda guardar el hilo no debe costarle la respuesta a la persona.
    Rails.logger.error("[Asistente] no se pudo guardar la conversación: #{e.message}")
    nil
  end

  # Los cambios viajan pegados al turno que los hizo: al retomar la sesión se siguen
  # viendo debajo de su mensaje. Al modelo no le vuelven (InterviewService solo deja
  # pasar role y content).
  def assistant_turn(result)
    respuesta = { 'role' => 'assistant', 'content' => result.reply.to_s }
    respuesta['changes'] = result.changes.deep_stringify_keys if result.changes.present?
    respuesta
  end

  # El cliente devuelve el hilo sin los cambios de turnos anteriores (y aunque los
  # mandara, no se le confían). Se recuperan de lo guardado, turno por turno, mientras
  # el contenido coincida: sin esto, cada turno nuevo borraría los cambios del anterior.
  def with_stored_changes(sesion, turnos)
    guardados = Array(sesion.messages)
    turnos.each_with_index.map do |turno, i|
      previo = guardados[i]
      next turno unless previo.is_a?(Hash) && previo['changes'].present? && previo['content'] == turno['content']

      turno.merge('changes' => previo['changes'])
    end
  end

  def session_record
    return nil if @params['session_id'].blank?

    TrackingAssistantSession.find_by(id: @params['session_id'], account: @account)
  end

  # Ya filtrado por el controlador (solo role y content, roles permitidos).
  def messages
    @messages ||= Array(@params['messages']).map { |m| m.to_h.stringify_keys.slice('role', 'content') }
  end

  def delivered_draft
    @params.key?('delivered_draft') ? @params['delivered_draft'].to_s : nil
  end

  def building
    @params.key?('building') ? ActiveModel::Type::Boolean.new.cast(@params['building']) : nil
  end
end
