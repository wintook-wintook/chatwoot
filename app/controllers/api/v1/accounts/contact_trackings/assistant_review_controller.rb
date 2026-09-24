# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REVISAR UNA CONVERSACIÓN REAL DESDE EL CHAT
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/conversation_review
#   { text, draft, inbox_id, turn_id, locale }
#   `text` es lo que la persona escribió en el chat: trae el link de la conversación
#   (…/conversations/173) y, si quiere, qué le pareció mal. Encola la revisión
#   (ConversationReviewJob) y responde 202. Ver ConversationReview.
#
# GET …/assistant/conversation_review/:turn_id
#   202 mientras trabaja; 200 con el resultado, o 422 con el error, al terminar.
#
# Aparte de AssistantController, que ya está en su tope de largo. Mismo permiso.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantReviewController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    result = ContactTrackings::Assistant::TurnProgress.read_result(Current.account, Current.user, params[:turn_id])
    return render json: { status: 'pending' }, status: :accepted if result.nil?
    return render json: result.slice('error'), status: :unprocessable_entity if result['error']

    render json: result
  end

  def create
    return render json: { error: 'invalid_turn_id' }, status: :unprocessable_entity unless valid_turn_id?

    display_id = ContactTrackings::Assistant::ConversationEvidence.display_id_in(params[:text], Current.account)
    return render json: { error: 'no_conversation' }, status: :unprocessable_entity if display_id.nil?
    return render json: { error: 'not_found' }, status: :unprocessable_entity unless conversation?(display_id)

    ContactTrackings::Assistant::ConversationReviewJob.perform_later(Current.account.id, Current.user.id, params[:turn_id],
                                                                     job_args(display_id))
    render json: { status: 'pending', display_id: display_id }, status: :accepted
  end

  private

  # La nota es el texto entero: lo que la persona dijo que estaba mal va ahí.
  def job_args(display_id)
    { 'display_id' => display_id, 'note' => params[:text].to_s, 'draft' => params[:draft].to_s,
      'inbox_id' => params[:inbox_id].presence, 'locale' => I18n.locale.to_s }
  end

  def valid_turn_id?
    params[:turn_id].to_s.match?(ContactTrackings::Assistant::TurnProgress::TURN_ID_RE)
  end

  def conversation?(display_id)
    Current.account.conversations.exists?(display_id: display_id)
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
