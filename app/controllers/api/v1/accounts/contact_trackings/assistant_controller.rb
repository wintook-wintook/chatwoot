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
#   hilo— y un turn_id. Encola el turno (InterviewJob) y responde 202.
#
# GET /api/v1/accounts/:account_id/contact_trackings/assistant/interview/:turn_id
#   202 mientras trabaja; al terminar, el mensaje del asistente, el Entrenamiento si
#   ya lo entregó y su comprobación (ver InterviewTurn), o 422 con el error.
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
    inventario = ContactTrackings::Assistant::InventoryService.new(Current.account, inbox: inbox).call
    render json: inventario.merge(models: models_for(inbox), catalog: ContactTrackings::Assistant::EngineCatalog.new(inventario).call)
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
    render json: TrackingAssistantSession.listable_for(Current.account)
                                         .map { |s| session_row(s) }
  end

  def show_session
    sesion = find_session
    return head :not_found if sesion.nil?

    render json: session_json(sesion)
  end

  # El texto de UNA versión: las listas viajan sin él (ver version_list).
  def show_version
    version = find_session&.version(params[:number])
    return head :not_found if version.nil?

    render json: { n: version['n'], draft: version['draft'] }
  end

  # En qué etapa está un turno que todavía no terminó (ver TurnProgress).
  def progress
    render json: ContactTrackings::Assistant::TurnProgress.read(Current.account, Current.user, params[:turn_id]) || {}
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

  # Encola el turno (InterviewJob) y responde 202: editar un Entrenamiento largo pasa
  # los 15 s de rack-timeout. La pantalla consulta #interview_result con el turn_id.
  def interview
    unless params[:turn_id].to_s.match?(ContactTrackings::Assistant::TurnProgress::TURN_ID_RE)
      return render json: { error: 'invalid_turn_id' }, status: :unprocessable_entity
    end

    ContactTrackings::Assistant::InterviewJob
      .perform_later(Current.account.id, Current.user.id, params[:turn_id], interview_args)
    render json: { status: 'pending' }, status: :accepted
  end

  # 202 mientras el job no terminó; 200 con el turno, o 422 con el error, al terminar.
  def interview_result
    result = ContactTrackings::Assistant::TurnProgress.read_result(Current.account, Current.user, params[:turn_id])
    return render json: { status: 'pending' }, status: :accepted if result.nil?
    return render json: result.slice('error'), status: :unprocessable_entity if result['error']

    render json: result
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

  # Lo que InterviewTurn necesita, en texto plano para ActiveJob. `delivered_draft` y
  # `building` solo viajan si vinieron: su ausencia significa algo (ver abajo).
  def interview_args
    args = { 'messages' => interview_messages, 'draft' => params[:draft], 'one_shot' => params[:one_shot],
             'session_id' => params[:session_id], 'inbox_id' => inbox&.id, 'locale' => I18n.locale.to_s }
    args['delivered_draft'] = delivered_draft if params.key?(:delivered_draft)
    args['building'] = building_param if params.key?(:building)
    args
  end

  def session_record
    return nil if params[:session_id].blank?

    TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account)
  end

  def close_session(template)
    session_record&.mark_saved!(template, draft: params[:draft])
  end

  # De la cuenta, no de quien pregunta: las conversaciones se comparten entre
  # administradores y cualquiera puede abrirlas, seguirlas y descartarlas.
  def find_session
    TrackingAssistantSession.find_by(id: params[:id], account: Current.account)
  end

  # Lo justo para elegir cuál abrir: de qué se trataba, en qué quedó, y qué iba a
  # leer el motor de ese borrador.
  #
  # `created_at` va además de `updated_at` porque son dos preguntas distintas:
  # cuándo se empezó a armar este agente, y cuándo se lo tocó por última vez. En
  # una entrevista que se retoma tres días después, la diferencia es el dato.
  #
  # `creator` importa desde que las conversaciones se comparten entre
  # administradores: en el listado hay trabajo de varias personas y hay que saber de
  # quién es cada una antes de seguirla. `mine` distingue las propias.
  def session_row(sesion)
    {
      id: sesion.id, status: sesion.status, title: sesion.title, named: sesion.name.present?,
      creator: sesion.user&.available_name || sesion.user&.name,
      mine: sesion.user_id == Current.user.id,
      routes: sesion.route_count, has_draft: sesion.draft.present?,
      tracking_template_id: sesion.tracking_template_id,
      template_name: sesion.tracking_template&.name,
      versions: sesion.version_list,
      created_at: sesion.created_at,
      updated_at: sesion.updated_at
    }
  end

  # Ver SessionPresenter: lo comparte InterviewTurn, que corre sin request.
  def session_json(sesion)
    ContactTrackings::Assistant::SessionPresenter.full(sesion, Current.user)
  end

  def save_params
    params.permit(:name, :objective, :ai_context, :inbox_id, :template_id, :session_id, calendar_integration_ids: [])
  end

  # nil = el cliente no sabe si la entrevista sigue abierta (se deduce de las marcas).
  def building_param
    params.key?(:building) ? ActiveModel::Type::Boolean.new.cast(params[:building]) : nil
  end

  # nil = el cliente no lo mandó (no sabe qué entregó el asistente) y no se detectan
  # ediciones a mano. "" = todavía no hubo entrega: todo lo que hay lo escribió la
  # persona. Por eso se mira si la llave vino, no si trae texto.
  def delivered_draft
    params.key?(:delivered_draft) ? params[:delivered_draft].to_s : nil
  end

  # Solo rol y contenido: el hilo lo manda el cliente y no se le confía nada más.
  def interview_messages
    Array(params[:messages]).map { |m| m.permit(:role, :content).to_h.to_hash }
                            .select { |m| ALLOWED_ROLES.include?(m['role']) && m['content'].present? }
  end

  # Con qué modelo va a clasificar y a contestar el agente en ese canal. La pantalla lo
  # muestra junto al selector: sin canal, la prueba de ruteo usa el modelo por defecto
  # y no el del agente, y eso cambia los resultados (medido: "usar" a secas no ruteaba
  # con gpt-4o-mini y sí con gpt-4o).
  def models_for(canal)
    { router: ContactTrackings::EngineConfig.model_for(canal, :router),
      conversational: ContactTrackings::EngineConfig.model_for(canal, :conversational) }
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
