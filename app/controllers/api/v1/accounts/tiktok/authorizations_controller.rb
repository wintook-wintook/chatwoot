class Api::V1::Accounts::Tiktok::AuthorizationsController < Api::V1::Accounts::BaseController
  include Tiktok::IntegrationHelper

  before_action :check_authorization
  before_action :ensure_channel_enabled

  def create
    render json: { success: true, url: Tiktok::AuthClient.authorize_url(state: generate_tiktok_token(Current.account.id)) }
  end

  private

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def ensure_channel_enabled
    return if Current.account.feature_enabled?('channel_tiktok')

    render json: { success: false, error: 'TikTok channel is not enabled for this account' }, status: :unprocessable_entity
  end
end
