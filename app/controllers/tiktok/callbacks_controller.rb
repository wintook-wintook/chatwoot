# Callback de la autorización de TikTok.
#
# TikTok redirige aquí sin sesión de usuario: la cuenta se recupera del `state` firmado
# que mandamos al iniciar el flujo. Ver Tiktok::IntegrationHelper.
class Tiktok::CallbacksController < ApplicationController
  include Tiktok::IntegrationHelper

  # La cuenta de TikTok ya está conectada en otra cuenta de Chatwoot
  class ForeignChannelError < StandardError; end

  def show
    rejection = rejection_reason
    return redirect_to_error(rejection) if rejection

    inbox = find_or_create_inbox
    redirect_to app_tiktok_inbox_agents_url(account_id: account.id, inbox_id: inbox.id)
  rescue ForeignChannelError
    redirect_to_error('already_connected')
  rescue StandardError => e
    Rails.logger.error("TikTok Channel creation Error: #{e.message}")
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    redirect_to_error('failed')
  end

  private

  # `nil` = se puede seguir. El orden importa: sin `state` válido no hay cuenta a la que
  # devolver al usuario, y sin código no se puede pedir el token.
  def rejection_reason
    return 'denied' if permitted_params[:error].present?
    return 'invalid_state' if account.blank?
    return 'missing_code' if permitted_params[:code].blank?
    # TikTok deja conceder los permisos a medias, y sin todos el canal no funciona: es
    # mejor rechazarlo aquí que dar de alta un inbox que no podrá leer ni enviar.
    return 'ungranted_scopes' unless all_scopes_granted?

    nil
  end

  def all_scopes_granted?
    granted = credentials[:scope].to_s.split(',')
    (Tiktok::AuthClient::REQUIRED_SCOPES - granted).blank?
  end

  def find_or_create_inbox
    details = business_account_details
    existing = Channel::Tiktok.find_by(business_id: credentials[:business_id])

    # El mismo business_id conectado en otra cuenta: no se le roba el canal a nadie.
    raise ForeignChannelError if existing.present? && existing.account_id != account.id

    channel = existing.present? ? reauthorize_channel(existing, details) : create_channel(details)
    channel.reauthorized!
    ::Avatar::AvatarFromUrlJob.perform_later(channel.inbox, details[:profile_image]) if details[:profile_image].present?

    channel.inbox
  end

  # Volver a autorizar es rehacer este mismo OAuth: se reconoce la cuenta por su
  # business_id y se refrescan credenciales en vez de crear un canal duplicado.
  def reauthorize_channel(channel, details)
    channel.update!(token_attributes)
    channel.inbox.update!(name: inbox_name(details))
    channel
  end

  def create_channel(details)
    ActiveRecord::Base.transaction do
      channel = account.tiktok_channels.create!(token_attributes.merge(business_id: credentials[:business_id]))
      account.inboxes.create!(account: account, channel: channel, name: inbox_name(details))
      channel
    end
  end

  def token_attributes
    credentials.slice(:access_token, :refresh_token, :expires_at, :refresh_token_expires_at)
  end

  def inbox_name(details)
    details[:display_name].presence || details[:username].presence || 'TikTok'
  end

  def business_account_details
    Tiktok::Client.new(business_id: credentials[:business_id], access_token: credentials[:access_token]).business_account_details
  end

  def credentials
    @credentials ||= Tiktok::AuthClient.obtain_short_term_access_token(permitted_params[:code])
  end

  def account
    @account ||= Account.find_by(id: verify_tiktok_token(permitted_params[:state]))
  end

  def redirect_to_error(reason)
    # Sin cuenta no hay a dónde volver dentro del dashboard.
    return redirect_to '/' if account.blank?

    redirect_to "#{app_new_tiktok_inbox_url(account_id: account.id)}?error=#{reason}"
  end

  def permitted_params
    params.permit(:code, :state, :error, :error_description, :scopes)
  end
end
