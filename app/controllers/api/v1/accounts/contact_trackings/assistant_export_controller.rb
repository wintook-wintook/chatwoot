# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F4: EXPORTAR
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/export
#   { name, draft, instructions, fields: { objective, ai_context, variables, datos_fijos } }
#   → { content, filename }  el .md de las instrucciones del agente (AgentExport).
#
# Lo arma el backend porque los datos fijos se sustituyen igual que en el motor
# (PromptConstants.expand). No guarda nada. El otro archivo del menú, los recursos del
# motor, sale del catálogo que la pantalla ya tiene (engineCatalogMarkdown.js).
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantExportController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def create
    campos = params[:fields].respond_to?(:permit) ? params[:fields].permit(*ContactTrackings::Assistant::DraftingFields::KEYS).to_h : {}
    render json: ContactTrackings::Assistant::AgentExport
      .new(name: params[:name], draft: params[:draft], instructions: params[:instructions], fields: campos).call
  end

  private

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
