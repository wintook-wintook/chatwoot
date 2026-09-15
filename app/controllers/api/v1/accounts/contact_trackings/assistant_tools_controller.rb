# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — HERRAMIENTAS SOBRE UN ENTRENAMIENTO (fase E de PROMPT STUDIO)
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/suggested_tests
#   Mensajes de cliente escritos por el modelo, pasados por el clasificador real, con
#   su veredicto. Ver SuggestedTests. Avisa el avance en `turn_id` (ver TurnProgress).
#
# Aparte de AssistantController: son herramientas que se aplican a un borrador ya
# escrito, no parte de la conversación, y aquel controlador ya estaba en su tope de
# largo. Mismo permiso: el Entrenamiento define cómo le contesta el bot a los clientes.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantToolsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :require_draft

  def suggested_tests
    avance = ContactTrackings::Assistant::TurnProgress.new(Current.account, Current.user, params[:turn_id])
    render json: ContactTrackings::Assistant::SuggestedTests
      .new(Current.account, draft: params[:draft], inbox: inbox, progress: avance.method(:update)).call
  end

  private

  def require_draft
    render json: { error: 'blank_draft' }, status: :unprocessable_entity if params[:draft].blank?
  end

  def inbox
    return nil if params[:inbox_id].blank?

    Current.account.inboxes.find_by(id: params[:inbox_id])
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
