# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONVERSAR PARA ARMAR UN AGENTE DESDE CERO
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/drafting_chat
#   { messages: [...], instructions: "el .md hasta ahora", session_id }
#   → { reply, instructions, changed, session_id, session }
#   Un turno de la conversación que llena las instrucciones iniciales (DraftingChat).
#   Se usa mientras no hay Entrenamiento; con uno en pantalla, el chat edita
#   (…/assistant/interview). Guarda el hilo y las instrucciones en la conversación
#   (TrackingAssistantSession), para retomarla desde «En construcción».
#
# Aparte de AssistantController, que ya está en su tope de largo. Mismo permiso.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantDraftingController < Api::V1::Accounts::BaseController
  ALLOWED_ROLES = %w[user assistant].freeze

  before_action :check_authorization

  def create
    result = ContactTrackings::Assistant::DraftingChat
             .new(Current.account, messages: messages, instructions: params[:instructions]).call
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    sesion = record(result)
    render json: result.slice(:reply, :instructions, :changed).merge(session_id: sesion&.id, session: session_meta(sesion))
  end

  private

  def messages
    Array(params[:messages]).map { |m| m.permit(:role, :content).to_h }
                            .select { |m| ALLOWED_ROLES.include?(m['role']) && m['content'].present? }
  end

  # Que no se pueda guardar el hilo no le cuesta la respuesta a la persona.
  def record(result)
    sesion = TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account) if params[:session_id].present?
    sesion ||= TrackingAssistantSession.new(account: Current.account, user: Current.user)
    turnos = messages + [{ 'role' => 'assistant', 'content' => result[:reply] }]
    sesion.record_turn(messages: turnos, instructions: result[:instructions])
    sesion
  rescue StandardError => e
    Rails.logger.error("[Asistente] no se pudo guardar la conversación: #{e.message}")
    nil
  end

  def session_meta(sesion)
    return nil if sesion.nil?

    { id: sesion.id, status: sesion.status, title: sesion.title,
      created_at: sesion.created_at, updated_at: sesion.updated_at }
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
