# proyecto@waba_chatwoot
# Api::V1::Accounts::Whatsapp::AuthorizationsController
#
# Endpoint: POST /api/v1/accounts/:account_id/whatsapp/authorization
#
# Recibe los datos del flujo de WhatsApp Embedded Signup desde el frontend
# y delega la creación del inbox a EmbeddedSignupService.
#
# Parámetros requeridos:
#   code         — Código OAuth de corta duración devuelto por FB.login()
#   business_id  — ID del negocio de Meta
#   waba_id      — ID de la cuenta de WhatsApp Business (WABA)
#
# Parámetros opcionales:
#   phone_number_id — ID del número específico a usar (si el WABA tiene varios)
#   inbox_id        — Si se envía, re-autoriza un inbox existente en lugar de crear uno nuevo
#
# Respuesta exitosa:
#   { success: true, id: <inbox_id>, name: <inbox_name>, channel_type: "whatsapp" }
#
class Api::V1::Accounts::Whatsapp::AuthorizationsController < Api::V1::Accounts::BaseController
  before_action :authorize_request

  def create
    channel = Whatsapp::EmbeddedSignupService.new(
      account: Current.account,
      params: embedded_signup_params
    ).perform
    render json: {
      success: true,
      id: channel.inbox.id,
      name: channel.inbox.name,
      channel_type: 'whatsapp'
    }
  rescue ArgumentError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] EmbeddedSignup error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_request
    authorize ::Inbox
  end

  def embedded_signup_params
    params.permit(:code, :business_id, :waba_id, :phone_number_id, :inbox_id)
  end
end
