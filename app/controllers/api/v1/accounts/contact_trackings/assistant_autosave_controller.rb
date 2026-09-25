# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — GUARDADO AUTOMÁTICO DE LO EDITADO A MANO
# ================================================================================
# PUT …/assistant/autosave  { draft, session_id }
#   → { session_id, session, versions }
#
# Pedido del usuario (25/09/2026): lo editado a mano solo quedaba guardado al mandar
# un mensaje o al guardar en el agente; cerrar la pestaña antes lo perdía. La pantalla
# lo manda unos segundos después de dejar de escribir. Sin conversación todavía (un
# prompt recién pegado), la crea: así aparece en «En construcción» para retomarla.
#
# Aparte de AssistantController, que ya está en su tope de largo. Mismo permiso.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantAutosaveController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def update
    draft = params[:draft].to_s
    return render json: { error: 'blank_draft' }, status: :unprocessable_entity if draft.strip.empty?

    sesion = find_session || TrackingAssistantSession.new(account: Current.account, user: Current.user)
    sesion.autosave!(draft)
    render json: { session_id: sesion.id, versions: sesion.version_list,
                   session: { id: sesion.id, status: sesion.status, title: sesion.title,
                              created_at: sesion.created_at, updated_at: sesion.updated_at } }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.first }, status: :unprocessable_entity
  end

  private

  def find_session
    return nil if params[:session_id].blank?

    TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account)
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
