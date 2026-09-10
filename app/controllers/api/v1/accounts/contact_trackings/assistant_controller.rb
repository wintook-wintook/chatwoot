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

  def interview
    result = ContactTrackings::Assistant::InterviewService
             .new(Current.account, messages: interview_messages, inbox: inbox,
                                   one_shot: ActiveModel::Type::Boolean.new.cast(params[:one_shot])).call

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    render json: {
      reply: result.reply,
      draft: result.draft,
      validation: result.validation,
      repairs: result.repairs,
      # Los datos del agente que el asistente propone. La pantalla los precarga
      # editables: un nombre propuesto y equivocado se ve y se corrige; un campo
      # vacío frena a quien acaba de explicar en la conversación lo que ahí va.
      proposal: result.proposal
    }
  end

  def save
    result = ContactTrackings::Assistant::SaveService
             .new(Current.account, user: Current.user, draft: params[:draft],
                                   mode: params[:mode], params: save_params).call

    return render json: { error: result.error, details: result.details }, status: :unprocessable_entity unless result.success?

    render json: { tracking_template_id: result.template.id, name: result.template.name }, status: :ok
  end

  private

  def save_params
    params.permit(:name, :objective, :ai_context, :inbox_id, :template_id)
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
