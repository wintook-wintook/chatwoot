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
# Cuelga de contact_trackings y no de un /assistant suelto a nivel cuenta: este
# asistente es del motor de Seguimientos, y Chatwoot ya tiene otro asistente propio
# (Captain) con el que no conviene confundirlo en la URL.
# ================================================================================
class Api::V1::Accounts::ContactTrackings::AssistantController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def inventory
    render json: ContactTrackings::Assistant::InventoryService.new(Current.account, inbox: inbox).call
  end

  def validate
    render json: ContactTrackings::Assistant::ValidatorService.new(params[:draft], account: Current.account).call
  end

  def interview
    result = ContactTrackings::Assistant::InterviewService
             .new(Current.account, messages: interview_messages, inbox: inbox).call

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    render json: {
      reply: result.reply,
      draft: result.draft,
      validation: result.validation,
      repairs: result.repairs
    }
  end

  private

  # Solo rol y contenido: el hilo lo manda el cliente y no se le confía nada más.
  def interview_messages
    Array(params[:messages]).map { |m| m.permit(:role, :content).to_h }
                            .select { |m| %w[user assistant].include?(m['role']) && m['content'].present? }
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
