class GoogleCalendarService
  CALENDAR_API = 'https://www.googleapis.com/calendar/v3'.freeze
  TOKEN_URL    = 'https://oauth2.googleapis.com/token'.freeze

  def initialize(integration)
    @integration = integration
    refresh_token_if_needed
  end

  def list_events(calendar_id: 'primary', time_min:, time_max:)
    response = get(
      "/calendars/#{CGI.escape(calendar_id)}/events",
      timeMin: time_min.utc.iso8601,
      timeMax: time_max.utc.iso8601,
      singleEvents: true,
      orderBy: 'startTime'
    )
    response['items'] || []
  end

  def create_event(calendar_id: 'primary', summary:, start_time:, end_time:, description: nil, attendees: [])
    body = {
      summary: summary,
      description: description,
      start: { dateTime: start_time.utc.iso8601, timeZone: 'UTC' },
      end:   { dateTime: end_time.utc.iso8601,   timeZone: 'UTC' },
      attendees: attendees.map { |email| { email: email } }
    }.compact

    post("/calendars/#{CGI.escape(calendar_id)}/events", body)
  end

  def update_event(event_id, calendar_id: 'primary', start_time:, end_time:, summary: nil, description: nil, attendees: nil)
    body = {
      start: { dateTime: start_time.utc.iso8601, timeZone: 'UTC' },
      end:   { dateTime: end_time.utc.iso8601,   timeZone: 'UTC' }
    }
    body[:summary]     = summary     if summary
    body[:description] = description if description
    body[:attendees]   = attendees.map { |e| { email: e } } if attendees
    patch("/calendars/#{CGI.escape(calendar_id)}/events/#{CGI.escape(event_id)}", body)
  end

  def free_busy(calendars:, time_min:, time_max:)
    body = {
      timeMin: time_min.utc.iso8601,
      timeMax: time_max.utc.iso8601,
      items: calendars.map { |id| { id: id } }
    }
    response = HTTParty.post(
      "#{CALENDAR_API}/freeBusy",
      headers: auth_headers,
      body: body.to_json
    )
    handle_response(response)
  end

  def refresh_token_if_needed
    return unless @integration.token_expired?

    response = HTTParty.post(
      TOKEN_URL,
      body: {
        client_id:     GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
        client_secret: GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil),
        refresh_token: @integration.refresh_token,
        grant_type:    'refresh_token'
      }
    )

    raise "Token refresh failed: #{response.body}" unless response.success?

    parsed = response.parsed_response
    @integration.update_tokens(
      access_token: parsed['access_token'],
      expires_at:   Time.current + parsed['expires_in'].to_i.seconds
    )
  end

  private

  def get(path, params = {})
    response = HTTParty.get(
      "#{CALENDAR_API}#{path}",
      headers: auth_headers,
      query: params
    )
    handle_response(response)
  end

  def patch(path, body)
    response = HTTParty.patch(
      "#{CALENDAR_API}#{path}",
      headers: auth_headers,
      body: body.to_json
    )
    handle_response(response)
  end

  def post(path, body)
    response = HTTParty.post(
      "#{CALENDAR_API}#{path}",
      headers: auth_headers,
      body: body.to_json
    )
    handle_response(response)
  end

  def auth_headers
    {
      'Authorization' => "Bearer #{@integration.access_token}",
      'Content-Type'  => 'application/json'
    }
  end

  def handle_response(response)
    raise "Google Calendar API error #{response.code}: #{response.body}" unless response.success?

    response.parsed_response
  end
end
