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
# Cuelga de contact_trackings y no de un /assistant suelto a nivel cuenta: este
# asistente es del motor de Seguimientos, y Chatwoot ya tiene otro asistente propio
# (Captain) con el que no conviene confundirlo en la URL.
# ================================================================================
class Api::V1::Accounts::ContactTrackings::AssistantController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def inventory
    render json: ContactTrackings::Assistant::InventoryService.new(Current.account, inbox: inbox).call
  end

  private

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
