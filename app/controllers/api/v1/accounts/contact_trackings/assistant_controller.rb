# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — Asistente de Agentes IA
# ================================================================================
# GET /api/v1/accounts/:account_id/contact_trackings/assistant/inventory
#   Devuelve lo que la cuenta tiene para armar un Entrenamiento: fuentes con su
#   directiva exacta, grupos de respuestas predefinidas, tipos de caso, etiquetas y
#   frases reales de clientes. Sin IA y de solo lectura.
#
#   Filtro opcional: inbox_id — acota las frases de clientes a ese canal. El resto
#   del inventario es de cuenta, así que no cambia.
#
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/validate
#   Recibe un Entrenamiento y devuelve qué va a leer el motor de él y qué no va a
#   ejecutar. Sin IA: lo revisa el parser real de produccion, así que es gratis e
#   instantáneo. Va separado de la conversación a propósito — el panel del
#   Entrenamiento es editable a mano y revalida en cada tecleo; si validar tuviera
#   que pasar por el modelo, editar sería lento y caro.
#
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/interview
#   Un turno de entrevista. Recibe la conversación completa —el cliente guarda el
#   hilo— y devuelve el mensaje del asistente, el Entrenamiento si ya lo entregó, y
#   su comprobación. Es el único endpoint del asistente que gasta tokens.
#
#   one_shot=true: sin entrevista, redacta de una. Lo usa el botón "generar" de la
#   ficha del Agente IA, donde no hay conversación en la que preguntar.
#
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/save
#   Lleva el borrador a un Agente IA: crea uno nuevo (mode=create) o reemplaza el
#   Entrenamiento de uno existente (mode=replace), guardando el anterior.
#   Rechaza el guardado si el comprobador encuentra algo bloqueante.
#
# GET /api/v1/accounts/:account_id/contact_trackings/assistant/audit
#   Pasa todos los Agentes IA de la cuenta por el comprobador y dice cuáles no
#   ejecutan lo que su nombre promete. Sin IA: son parseos, no llamadas.
#
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/dry_run
#   Corre UNA pregunta contra el Entrenamiento sin enviar nada: rama elegida, fuente
#   consultada, fragmentos con su similitud, etiqueta y si abriría un caso. Es lo que
#   el comprobador no puede contestar — un Entrenamiento puede parsear perfecto y
#   rutear todo a la rama equivocada. Gasta tokens (clasificación + embedding), así
#   que se dispara con un botón y nunca sola.
#
# GET /api/v1/accounts/:account_id/contact_trackings/assistant/session
#   La conversación a medias de quien pregunta, si la hay. Se ofrece retomar al
#   abrir la pantalla: una entrevista dura 30–45 minutos y cerrar la pestaña no
#   debería tirarla.
#
# GET    .../assistant/sessions        las conversaciones de quien pregunta
# GET    .../assistant/sessions/:id    una, para retomarla
# DELETE .../assistant/sessions/:id    descartarla
#   Un Entrenamiento bueno rara vez sale de una sentada: se deja a medias, se
#   vuelve, se compara con el de otro intento. Sin listado, cada conversación era
#   un callejón sin salida salvo la última.
#
# Cuelga de contact_trackings y no de un /assistant suelto a nivel cuenta: este
# asistente es del motor de Seguimientos, y Chatwoot ya tiene otro asistente propio
# (Captain) con el que no conviene confundirlo en la URL.
# ================================================================================
class Api::V1::Accounts::ContactTrackings::AssistantController < Api::V1::Accounts::BaseController
  # El hilo de la entrevista lo manda el cliente: solo se aceptan estos dos roles, para
  # que nadie pueda inyectar un `system` propio y reescribir el contrato del motor.
  ALLOWED_ROLES = %w[user assistant].freeze

  before_action :check_authorization

  def inventory
    render json: ContactTrackings::Assistant::InventoryService.new(Current.account, inbox: inbox).call
  end

  def validate
    render json: ContactTrackings::Assistant::ValidatorService.new(params[:draft], account: Current.account).call
  end

  def audit
    render json: ContactTrackings::Assistant::AuditService.new(Current.account).call
  end

  # Prueba en seco: qué haría el motor con UNA pregunta. No envía nada ni escribe
  # nada; lo único que gasta es la clasificación de rama y el embedding.
  def dry_run
    result = ContactTrackings::Assistant::DryRunService
             .new(Current.account, draft: params[:draft], question: params[:question], inbox: inbox).call

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    render json: result.payload
  end

  # Se llama `resume` y no `session`: `session` es el hash de sesión de
  # ActionController, y definirlo acá lo pisa y rompe TODO el controlador con un
  # 500 — incluidos los endpoints que no tienen nada que ver.
  def resume
    sesion = TrackingAssistantSession.resumable_for(Current.account, Current.user)
    return render json: nil if sesion.nil?

    render json: session_json(sesion)
  end

  def sessions
    render json: TrackingAssistantSession.listable_for(Current.account, Current.user)
                                         .map { |s| session_row(s) }
  end

  def show_session
    sesion = find_session
    return head :not_found if sesion.nil?

    render json: session_json(sesion)
  end

  # Descartar no borra la fila: la marca. Un clic de más en una entrevista de 40
  # minutos no debería ser irreversible, y para quien mira la pantalla el efecto
  # es el mismo — deja de aparecer.
  def discard_session
    sesion = find_session
    return head :not_found if sesion.nil?

    sesion.update!(status: 'discarded')
    head :no_content
  end

  def interview
    result = ContactTrackings::Assistant::InterviewService
             .new(Current.account, messages: interview_messages, inbox: inbox,
                                   one_shot: ActiveModel::Type::Boolean.new.cast(params[:one_shot])).call

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    sesion = record_turn(result)

    render json: {
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
      session_id: sesion&.id,
      # La identidad completa y no solo el id: con el id suelto, la pantalla
      # tendría que inventar las fechas del lado del cliente.
      session: sesion && session_json(sesion).except(:messages, :draft, :validation, :proposal)
    }
  end

  def save
    result = ContactTrackings::Assistant::SaveService
             .new(Current.account, user: Current.user, draft: params[:draft],
                                   mode: params[:mode], params: save_params).call

    return render json: { error: result.error, details: result.details }, status: :unprocessable_entity unless result.success?

    close_session(result.template)

    # `warnings` no es un error: el agente se guardó. Son las directivas que
    # dependen de la configuración del AGENTE y que el comprobador no podía
    # revisar sobre un borrador, porque el agente todavía no existía.
    render json: { tracking_template_id: result.template.id, name: result.template.name,
                   warnings: result.warnings.presence }, status: :ok
  end

  private

  # El hilo se guarda después de contestar, no antes: si la llamada al modelo falla
  # no queda una sesión a medias que la pantalla ofrezca retomar sin contenido.
  def record_turn(result)
    sesion = session_record || TrackingAssistantSession.new(account: Current.account, user: Current.user)
    turnos = interview_messages + [{ 'role' => 'assistant', 'content' => result.reply.to_s }]
    sesion.record_turn(messages: turnos, draft: result.draft,
                       validation: result.validation, proposal: result.proposal)
    sesion
  rescue StandardError => e
    # Que no se pueda guardar el hilo no debe costarle la respuesta a la persona.
    Rails.logger.error("[Asistente] no se pudo guardar la conversación: #{e.message}")
    nil
  end

  def session_record
    return nil if params[:session_id].blank?

    TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account, user: Current.user)
  end

  def close_session(template)
    session_record&.mark_saved!(template)
  end

  def find_session
    TrackingAssistantSession.find_by(id: params[:id], account: Current.account, user: Current.user)
  end

  # Lo justo para elegir cuál abrir: de qué se trataba, en qué quedó, y qué iba a
  # leer el motor de ese borrador.
  #
  # `created_at` va además de `updated_at` porque son dos preguntas distintas:
  # cuándo se empezó a armar este agente, y cuándo se lo tocó por última vez. En
  # una entrevista que se retoma tres días después, la diferencia es el dato.
  #
  # NO se devuelve quién la creó, y no por olvido: `listable_for` filtra por
  # usuario y todas las acciones buscan con `find_by(id:, account:, user:)`, así
  # que cada quien ve únicamente las suyas. La columna sería siempre la misma
  # persona. Si algún día se comparten entre administradores, ahí sí hace falta.
  def session_row(sesion)
    {
      id: sesion.id, status: sesion.status, title: sesion.title,
      routes: sesion.route_count, has_draft: sesion.draft.present?,
      tracking_template_id: sesion.tracking_template_id,
      template_name: sesion.tracking_template&.name,
      created_at: sesion.created_at,
      updated_at: sesion.updated_at
    }
  end

  # Al retomar una conversación se devuelve además su identidad —id, estado,
  # cuándo se creó, de qué Agente IA salió—, no solo su contenido: la pantalla del
  # Asistente mostraba el hilo y el borrador sin decir en CUÁL de las
  # conversaciones estabas trabajando. Con doce en el listado, eso es un problema
  # real: se retoma una, se la confunde con otra, y se guarda encima del agente
  # equivocado.
  def session_json(sesion)
    {
      id: sesion.id, messages: sesion.messages, draft: sesion.draft,
      validation: sesion.validation.presence, proposal: sesion.proposal.presence,
      tracking_template_id: sesion.tracking_template_id,
      status: sesion.status,
      # De qué se trataba: el primer mensaje de la persona. Es lo que el card de
      # referencia muestra arriba de la conversación.
      title: sesion.title,
      template_name: sesion.tracking_template&.name,
      created_at: sesion.created_at,
      updated_at: sesion.updated_at
    }
  end

  def save_params
    params.permit(:name, :objective, :ai_context, :inbox_id, :template_id, :session_id)
  end

  # Solo rol y contenido: el hilo lo manda el cliente y no se le confía nada más.
  def interview_messages
    Array(params[:messages]).map { |m| m.permit(:role, :content).to_h }
                            .select { |m| ALLOWED_ROLES.include?(m['role']) && m['content'].present? }
  end

  def inbox
    return nil if params[:inbox_id].blank?

    Current.account.inboxes.find_by(id: params[:inbox_id])
  end

  # El Entrenamiento define cómo le contesta el bot a los clientes de la cuenta, y el
  # inventario expone mensajes entrantes reales: es material de administración.
  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
