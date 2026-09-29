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
# PATCH …/assistant/sessions/:id/name  { name }
#   Nombre puesto a mano a la conversación (vacío lo quita y vuelve el automático).
#   Pedido del usuario, 25/09/2026: varias se llamaban igual.
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
    render json: { session_id: sesion.id, versions: sesion.version_list, session: meta(sesion) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.first }, status: :unprocessable_entity
  end

  def rename
    sesion = find_session
    return head :not_found if sesion.nil?

    sesion.update!(name: params[:name].to_s.squish.presence)
    render json: { id: sesion.id, title: sesion.title, named: sesion.name.present? }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.first }, status: :unprocessable_entity
  end

  private

  def meta(sesion)
    { id: sesion.id, status: sesion.status, title: sesion.title, named: sesion.name.present?,
      created_at: sesion.created_at, updated_at: sesion.updated_at }
  end

  # :id en la ruta de renombrar; session_id en el cuerpo del guardado automático.
  def find_session
    id = params[:id].presence || params[:session_id].presence
    return nil if id.nil?

    TrackingAssistantSession.find_by(id: id, account: Current.account)
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
