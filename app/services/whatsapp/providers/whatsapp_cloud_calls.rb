# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F2) — LA CALLING API DE META
# ================================================================================
# Se incluye en WhatsappCloudService. Portado de la v4.19
# (enterprise/app/services/enterprise/whatsapp/providers/whatsapp_cloud_service.rb).
#
#   contestar        pre_accept_call + accept_call (con el SDP answer del navegador)
#   rechazar/colgar  reject_call / terminate_call
#   llamar           initiate_call (SDP offer)  → NoCallPermission si falta permiso (138006)
#   pedir permiso    send_call_permission_request (mensaje interactivo)
#   activar          update_calling_status ('ENABLED' / 'DISABLED', y si se ve el botón)
#   leer             calling_settings
#
# Graph v22.0 (Meta pide v17+ para llamadas); el resto del servicio sigue en sus versiones.
# Las acciones devuelven true/false y no levantan: quien llama decide qué hacer si Meta
# rechaza. initiate_call y update_calling_status sí levantan con el mensaje de Meta.
# Plan: docs/llamadas_whatsapp_plan.md
# ================================================================================
module Whatsapp::Providers::WhatsappCloudCalls
  CALLING_API_VERSION = 'v22.0'

  def pre_accept_call(call_id, sdp_answer)
    call_action('pre_accept_call', call_id, 'pre_accept', sdp_answer)
  end

  def accept_call(call_id, sdp_answer)
    call_action('accept_call', call_id, 'accept', sdp_answer)
  end

  def reject_call(call_id)
    call_action('reject_call', call_id, 'reject')
  end

  def terminate_call(call_id)
    call_action('terminate_call', call_id, 'terminate')
  end

  # Devuelve la respuesta de Meta ({ 'calls' => [{ 'id' => … }] }).
  def initiate_call(recipient, sdp_offer)
    body = { messaging_product: 'whatsapp', to: recipient.to_s.delete('+'), action: 'connect',
             session: { sdp: sdp_offer, sdp_type: 'offer' } }
    response = HTTParty.post("#{calls_phone_path}/calls", headers: api_headers, body: body.to_json)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] initiate_call failed: status=#{response.code} body=#{response.body}"
    error = meta_error(response)
    raise Voice::CallErrors::NoCallPermission, meta_error_message(error) if error['code'] == Voice::CallErrors::NO_CALL_PERMISSION_CODE

    raise Voice::CallErrors::CallFailed, meta_error_message(error, 'No se pudo iniciar la llamada')
  end

  # El mensaje interactivo con el botón «Permitir llamadas». Devuelve la respuesta de Meta
  # (con el wamid, para reconocer la respuesta del cliente) o nil si falló.
  def send_call_permission_request(recipient, body_text)
    body = { messaging_product: 'whatsapp', recipient_type: 'individual', to: recipient.to_s.delete('+'),
             type: 'interactive',
             interactive: { type: 'call_permission_request', action: { name: 'call_permission_request' },
                            body: { text: body_text } } }
    response = HTTParty.post("#{calls_phone_path}/messages", headers: api_headers, body: body.to_json)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] send_call_permission_request failed: status=#{response.code} body=#{response.body}"
    nil
  end

  # status: 'ENABLED' / 'DISABLED'. icon: 'DEFAULT' (el cliente ve el botón de llamar) o
  # 'DISABLE_ALL' (no lo ve; «solo salientes»). Levanta con el mensaje de Meta si falla.
  def update_calling_status(status, icon: nil)
    calling = { status: status }
    calling[:call_icon_visibility] = icon if icon
    response = HTTParty.post("#{calls_phone_path}/settings", headers: api_headers, body: { calling: calling }.to_json)
    return true if response.success?

    Rails.logger.error "[WHATSAPP CALL] update_calling_status failed: status=#{response.code} body=#{response.body}"
    raise meta_error_message(meta_error(response), 'No se pudo cambiar la configuración de llamadas en Meta')
  end

  # { 'status' => 'ENABLED'|'DISABLED'|'NOT_SET', 'call_icon_visibility' => …, … } o nil.
  def calling_settings
    response = HTTParty.get("#{calls_phone_path}/settings", headers: api_headers)
    response.success? ? response.parsed_response['calling'] : nil
  end

  private

  def calls_phone_path
    "#{api_base_path}/#{CALLING_API_VERSION}/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  # El SDP no va al log: es largo y trae direcciones de red.
  def call_action(name, call_id, action, sdp_answer = nil)
    body = { messaging_product: 'whatsapp', call_id: call_id, action: action }
    body[:session] = { sdp: sdp_answer, sdp_type: 'answer' } if sdp_answer
    response = HTTParty.post("#{calls_phone_path}/calls", headers: api_headers, body: body.to_json)
    Rails.logger.error "[WHATSAPP CALL] #{name} failed: status=#{response.code} body=#{response.body}" unless response.success?
    response.success?
  end

  def meta_error(response)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    parsed['error'].is_a?(Hash) ? parsed['error'] : {}
  end

  # Meta a veces manda error_user_msg vacío: se toma el primero que tenga texto.
  def meta_error_message(error, default = 'Error de Meta')
    error['error_user_msg'].presence || error['message'].presence || error['error_user_title'].presence || default
  end
end
