# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — LLAMADAS DE WHATSAPP DESDE EL DASHBOARD
# ================================================================================
#   GET  whatsapp_calls/:id             la llamada (para el widget al recargar)
#   POST whatsapp_calls/:id/accept      { sdp_answer }   contestar
#   POST whatsapp_calls/:id/reject                       rechazar
#   POST whatsapp_calls/:id/terminate                    colgar
#   POST whatsapp_calls/initiate        { conversation_id, sdp_offer }  llamar
#
# Pueden usarlo los agentes de la bandeja y los administradores (P4).
#   409  otro agente ya contestó, o la llamada ya terminó: el dashboard quita el timbre
#   422  error de la llamada, o (initiate) hubo que pedir permiso / se llegó al límite:
#        { status: permission_requested | permission_limit, next_allowed_at? }
# Llamar solo desde una conversación por ahora (desde la ficha del contacto: después).
# Portado de la v4.19 (enterprise/app/controllers/api/v1/accounts/whatsapp_calls_controller.rb).
# ================================================================================
class Api::V1::Accounts::WhatsappCallsController < Api::V1::Accounts::BaseController
  before_action :set_call, only: %i[show accept reject terminate]
  before_action :set_conversation, only: :initiate
  before_action :ensure_inbox_access
  before_action :ensure_outbound_allowed, :ensure_sdp_offer, only: :initiate

  rescue_from Voice::CallErrors::NotRinging, Voice::CallErrors::CallFailed, with: :render_call_error
  rescue_from Voice::CallErrors::AlreadyAccepted, Voice::CallErrors::CallAlreadyEnded, with: :render_conflict

  def show
    render json: call_json
  end

  def accept
    call_service.accept
    render json: call_json
  end

  def reject
    call_service.reject
    render json: call_json
  end

  def terminate
    call_service.terminate
    render json: call_json
  end

  def initiate
    respuesta = @inbox.channel.calls_provider.initiate_call(recipient, params[:sdp_offer])
    @call = create_outbound_call(respuesta.dig('calls', 0, 'id') || respuesta['call_id'])
    render json: call_json
  rescue Voice::CallErrors::NoCallPermission
    render_permission_request
  end

  private

  def set_call
    @call = Current.account.calls.whatsapp.find(params[:id])
    @inbox = @call.inbox
  end

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    @inbox = @conversation.inbox
  end

  # P4: los agentes de la bandeja y los administradores.
  def ensure_inbox_access
    return if Current.account_user&.administrator? || @inbox.members.exists?(id: Current.user.id)

    render json: { error: I18n.t('errors.whatsapp.calls.not_allowed') }, status: :forbidden
  end

  def ensure_outbound_allowed
    return if @inbox.channel.try(:outbound_calls_allowed?)

    render_unprocessable(I18n.t('errors.whatsapp.calls.outbound_disabled'))
  end

  def ensure_sdp_offer
    render_unprocessable(I18n.t('errors.whatsapp.calls.sdp_offer_required')) if params[:sdp_offer].blank?
  end

  # El source_id del contact_inbox es el wa_id con el que WhatsApp conoce al cliente.
  def recipient
    @conversation.contact_inbox&.source_id.presence || @conversation.contact.phone_number.to_s.delete('+')
  end

  def call_service
    Whatsapp::CallService.new(call: @call, agent: Current.user, sdp_answer: params[:sdp_answer])
  end

  # La fila se crea después de que Meta aceptó llamar: un intento fallido no deja nada.
  def create_outbound_call(provider_call_id)
    existente = Call.whatsapp.find_by(provider_call_id: provider_call_id)
    return existente if existente

    call = Current.account.calls.create!(
      inbox: @inbox, conversation: @conversation, contact: @conversation.contact, provider: :whatsapp,
      provider_call_id: provider_call_id, direction: :outgoing, status: 'ringing', accepted_by_agent: Current.user,
      meta: { 'sdp_offer' => params[:sdp_offer], 'ice_servers' => Call.default_ice_servers, 'initiated_at' => Time.zone.now.to_i }
    )
    call.update!(message: Voice::CallMessageBuilder.new(call).perform!)
    @conversation.update!(assignee: Current.user) if @conversation.assignee_id.nil?
    call
  rescue ActiveRecord::RecordNotUnique
    Call.whatsapp.find_by!(provider_call_id: provider_call_id)
  end

  def render_permission_request
    resultado = Whatsapp::CallPermissionRequestService.new(conversation: @conversation, recipient: recipient,
                                                           requester: Current.user).perform
    return render_unprocessable(I18n.t('errors.whatsapp.calls.permission_request_failed')) if resultado[:status] == 'failed'

    render json: resultado.merge(conversation_id: @conversation.display_id), status: :unprocessable_entity
  end

  def call_json
    @call.reload.push_event_data.merge(sdp_offer: @call.sdp_offer, ice_servers: @call.ice_servers,
                                       recording_enabled: @call.recording_enabled?)
  end

  def render_unprocessable(mensaje)
    render json: { error: mensaje }, status: :unprocessable_entity
  end

  def render_call_error(error)
    render_unprocessable(error.message)
  end

  def render_conflict(error)
    render json: { error: error.message }, status: :conflict
  end
end
