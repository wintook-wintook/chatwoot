class GoogleCalendarCallbackController < ApplicationController
  include GoogleConcern

  def show
    state_payload = ::Redis::Alfred.get("google_calendar::state::#{state_token}")

    unless state_payload
      redirect_to '/' and return
    end

    payload = JSON.parse(state_payload)
    user = User.find(payload['user_id'])
    account = Account.find(payload['account_id'])

    response = google_client.auth_code.get_token(
      params[:code],
      redirect_uri: "#{base_url}/google_calendar/callback"
    )

    parsed = response.response.parsed
    id_token_data = JWT.decode(parsed['id_token'], nil, false)[0] rescue {}
    google_email = id_token_data['email'] || parsed['email']

    integration = UserCalendarIntegration.find_or_initialize_by(user: user, account: account)
    integration.google_email = google_email
    integration.save! if integration.new_record?

    integration.update_tokens(
      access_token: parsed['access_token'],
      refresh_token: parsed['refresh_token'],
      expires_at: Time.current + parsed['expires_in'].to_i.seconds
    )

    ::Redis::Alfred.delete("google_calendar::state::#{state_token}")

    redirect_to "/app/accounts/#{account.id}/google-calendar?oauth=success"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    redirect_to '/'
  end

  private

  def state_token
    params[:state]
  end
end
