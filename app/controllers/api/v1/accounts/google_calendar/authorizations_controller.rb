class Api::V1::Accounts::GoogleCalendar::AuthorizationsController < Api::V1::Accounts::BaseController
  include GoogleConcern

  CALENDAR_SCOPES = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
    'email',
    'profile'
  ].freeze

  def create
    state_token = SecureRandom.hex(24)
    redirect_url = google_client.auth_code.authorize_url(
      redirect_uri: "#{base_url}/google_calendar/callback",
      scope: CALENDAR_SCOPES.join(' '),
      response_type: 'code',
      prompt: 'consent',
      access_type: 'offline',
      client_id: GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
      state: state_token
    )

    ::Redis::Alfred.setex(
      "google_calendar::state::#{state_token}",
      { user_id: current_user.id, account_id: Current.account.id }.to_json,
      30.minutes
    )

    render json: { success: true, url: redirect_url }
  end

  def destroy
    integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    return render json: { success: false }, status: :not_found unless integration

    revoke_google_token(integration.access_token)
    integration.destroy!
    render json: { success: true }
  end

  private

  def revoke_google_token(token)
    return if token.blank?

    HTTParty.post(
      'https://oauth2.googleapis.com/revoke',
      query: { token: token },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    )
  rescue StandardError => e
    Rails.logger.error "GoogleCalendar token revoke error: #{e.message}"
  end
end
