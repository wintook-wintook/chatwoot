# Callback de "Instagram API with Instagram Login".
#
# Meta redirige aquí sin sesión de usuario, así que la cuenta se recupera del `state`
# que guardamos en Redis al iniciar la autorización.
class Instagram::CallbacksController < ApplicationController
  def show
    return redirect_to_error('denied') if permitted_params[:error].present?
    return redirect_to_error('invalid_state') if account.blank?
    return redirect_to_error('missing_code') if permitted_params[:code].blank?

    inbox = create_channel_with_inbox
    ::Redis::Alfred.delete(cache_key)

    redirect_to app_instagram_inbox_agents_url(account_id: account.id, inbox_id: inbox.id)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    redirect_to_error('failed')
  end

  private

  def create_channel_with_inbox
    profile = fetch_authorized_profile

    ActiveRecord::Base.transaction do
      channel = account.instagram_channels.create!(
        instagram_id: profile[:instagram_id],
        access_token: profile[:access_token],
        expires_at: profile[:expires_at],
        provider_config: profile[:provider_config]
      )
      inbox = account.inboxes.create!(name: profile[:name], channel: channel)
      ::Avatar::AvatarFromUrlJob.perform_later(inbox, profile[:avatar_url]) if profile[:avatar_url].present?
      inbox
    end
  end

  # Tres saltos contra Meta: código -> token corto -> token largo (60 días) -> perfil.
  def fetch_authorized_profile
    short_lived = oauth_service.exchange_code(permitted_params[:code])
    long_lived = oauth_service.exchange_long_lived_token(short_lived[:access_token])
    access_token = long_lived[:access_token]
    profile = oauth_service.fetch_profile(access_token)

    {
      # `user_id` es el IGSID de la cuenta de negocio, que es con el que llegan los webhooks.
      # Si Meta no lo devuelve, caemos al `user_id` del intercambio del código.
      instagram_id: (profile[:user_id] || short_lived[:user_id]).to_s,
      access_token: access_token,
      expires_at: expires_at_from(long_lived),
      avatar_url: profile[:profile_picture_url],
      name: profile[:username].presence || profile[:name].presence || 'Instagram',
      provider_config: {
        username: profile[:username],
        name: profile[:name],
        profile_picture_url: profile[:profile_picture_url]
      }
    }
  end

  def expires_at_from(long_lived)
    expires_in = long_lived[:expires_in].to_i
    return if expires_in.zero?

    Time.current + expires_in.seconds
  end

  def oauth_service
    @oauth_service ||= ::Instagram::OauthService.new
  end

  def account
    @account ||= Account.find_by(id: ::Redis::Alfred.get(cache_key))
  end

  def cache_key
    format(::Redis::Alfred::IG_OAUTH_STATE, state: permitted_params[:state])
  end

  def redirect_to_error(reason)
    # Sin cuenta no hay a dónde volver dentro del dashboard.
    return redirect_to '/' if account.blank?

    redirect_to "#{app_new_instagram_inbox_url(account_id: account.id)}?error=#{reason}"
  end

  def permitted_params
    params.permit(:code, :state, :error, :error_reason, :error_description)
  end
end
