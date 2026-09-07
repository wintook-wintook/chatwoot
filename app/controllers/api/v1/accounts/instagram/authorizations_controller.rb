class Api::V1::Accounts::Instagram::AuthorizationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_channel_enabled

  def create
    state = SecureRandom.hex(24)
    # El callback llega sin sesión, así que dejamos la cuenta guardada bajo el `state`.
    # Caduca en 10 minutos: es una autorización interactiva, no debería tardar más.
    ::Redis::Alfred.setex(cache_key(state), Current.account.id, 10.minutes)

    render json: { success: true, url: oauth_service.authorize_url(state: state) }
  end

  private

  def oauth_service
    @oauth_service ||= ::Instagram::OauthService.new
  end

  def cache_key(state)
    format(::Redis::Alfred::IG_OAUTH_STATE, state: state)
  end

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def ensure_channel_enabled
    return if Current.account.feature_enabled?('channel_instagram')

    render json: { success: false, error: 'Instagram channel is not enabled for this account' }, status: :unprocessable_entity
  end
end
