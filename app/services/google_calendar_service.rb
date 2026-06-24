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

  def create_event(calendar_id: 'primary', summary:, start_time: nil, end_time: nil, due_date: nil, end_date: nil, all_day: false, description: nil, attendees: [])
    body = { summary: summary, description: description }

    if all_day
      date = due_date.presence || start_time&.to_date&.iso8601 || Date.today.iso8601
      parsed_end = end_date.presence ? Date.parse(end_date) : nil
      parsed_start = Date.parse(date)
      end_date_val = (parsed_end && parsed_end > parsed_start ? parsed_end : parsed_start + 1).iso8601
      body[:start] = { date: date }
      body[:end]   = { date: end_date_val }
    else
      body[:start] = { dateTime: start_time.utc.iso8601, timeZone: 'UTC' }
      body[:end]   = { dateTime: end_time.utc.iso8601,   timeZone: 'UTC' }
      body[:attendees] = attendees.map { |email| { email: email } } if attendees.any?
    end

    # sendUpdates=all: Google envía el correo de invitación (.ics) a TODOS los invitados,
    # de cualquier dominio (no solo gmail). Sin esto, los invitados no-Google no se enteran.
    post("/calendars/#{CGI.escape(calendar_id)}/events", body.compact, query: { sendUpdates: 'all' })
  end

  def update_event(event_id, calendar_id: 'primary', start_time:, end_time:, summary: nil, description: nil, attendees: nil)
    body = {
      start: { dateTime: start_time.utc.iso8601, timeZone: 'UTC' },
      end:   { dateTime: end_time.utc.iso8601,   timeZone: 'UTC' }
    }
    body[:summary]     = summary     if summary
    body[:description] = description if description
    body[:attendees]   = attendees.map { |e| { email: e } } if attendees
    # sendUpdates=all: notifica por correo a los invitados (de cualquier dominio) al mover la cita.
    patch("/calendars/#{CGI.escape(calendar_id)}/events/#{CGI.escape(event_id)}", body, query: { sendUpdates: 'all' })
  end

  # Borra un evento. `delete` lanza ante un error real de la API; si Google responde
  # 404/410 (el evento ya no existe) lo tratamos como éxito idempotente. Por eso, si
  # no se levantó excepción, el evento ya no está en el calendario → devolvemos true.
  def delete_event(event_id, calendar_id: 'primary')
    delete("/calendars/#{CGI.escape(calendar_id)}/events/#{CGI.escape(event_id)}")
    true
  end

  # Zona horaria de la cuenta de Google (la que el usuario ve en su Google Calendar).
  # Google muestra los eventos en ESTA zona sin importar el `timeZone` con que se creó el
  # evento. Anclar el bot a esta zona evita que la hora del chat y la del calendario difieran.
  # Devuelve el IANA tz (p.ej. "America/Mexico_City") o nil si la API falla.
  def account_timezone
    response = get('/users/me/settings/timezone')
    response['value'].presence
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarService] ⚠️ account_timezone falló: #{e.message}"
    nil
  end

  def list_calendars
    response = get('/users/me/calendarList')
    (response['items'] || []).map do |cal|
      {
        id: cal['id'],
        summary: cal['summary'],
        background_color: cal['backgroundColor'] || '#6366f1',
        foreground_color: cal['foregroundColor'] || '#ffffff',
        primary: cal['primary'] || false,
        access_role: cal['accessRole']
      }
    end
  end

  def subscribe_calendar(calendar_id)
    response = HTTParty.post(
      "#{CALENDAR_API}/users/me/calendarList",
      headers: auth_headers,
      body: { id: calendar_id }.to_json
    )
    handle_response(response)
  end

  def list_events_for_calendars(calendar_ids:, time_min:, time_max:)
    calendar_ids.flat_map do |cal_id|
      list_events(calendar_id: cal_id, time_min: time_min, time_max: time_max)
        .map { |e| e.merge('calendarId' => cal_id) }
    end.sort_by { |e| e.dig('start', 'dateTime') || e.dig('start', 'date') || '' }
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

  def patch(path, body, query: {})
    response = HTTParty.patch(
      "#{CALENDAR_API}#{path}",
      headers: auth_headers,
      body: body.to_json,
      query: query
    )
    handle_response(response)
  end

  def post(path, body, query: {})
    response = HTTParty.post(
      "#{CALENDAR_API}#{path}",
      headers: auth_headers,
      body: body.to_json,
      query: query
    )
    handle_response(response)
  end

  def delete(path)
    response = HTTParty.delete("#{CALENDAR_API}#{path}", headers: auth_headers)
    # Un evento que ya no existe (404/410) es un borrado idempotente, no un error.
    return :already_gone if [404, 410].include?(response.code)

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
