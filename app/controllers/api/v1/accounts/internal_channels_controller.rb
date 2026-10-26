# frozen_string_literal: true

# feat/chat_interno (plan v2, R1) — LA BANDEJA «INTERNO»
# GET  /api/v1/accounts/:account_id/internal_channel           la deja lista y da su id
# POST /api/v1/accounts/:account_id/internal_channel/directs   { user_id } → el directo con ese
#                                                               agente (lo crea si no existe)
# Con el chat apagado en la cuenta responde 404.
class Api::V1::Accounts::InternalChannelsController < Api::V1::Accounts::BaseController
  before_action :ensure_enabled

  def show
    inbox = InternalChannel::Setup.new(Current.account).call
    render json: { inbox_id: inbox.id }
  end

  def directs
    conversation = InternalChannel::Direct.new(account: Current.account, user: Current.user).open!(params[:user_id])
    render json: { conversation_id: conversation.display_id, inbox_id: conversation.inbox_id }, status: :created
  rescue InternalChannel::Direct::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def ensure_enabled
    head :not_found unless Current.account.internal_chat_enabled?
  end
end
