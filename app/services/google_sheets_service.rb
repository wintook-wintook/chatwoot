# @knowledge_sources — Base de Conocimiento / Google Sheets
#
# Lee los valores de una hoja vía Sheets API (solo lectura) y los devuelve como
# encabezados + filas (array de hashes { encabezado => valor }). Reutiliza la
# conexión OAuth de Google (UserCalendarIntegration + scope spreadsheets.readonly).
class GoogleSheetsService
  SHEETS_API = 'https://sheets.googleapis.com/v4'.freeze
  TOKEN_URL  = 'https://oauth2.googleapis.com/token'.freeze
  DEFAULT_RANGE = 'A1:Z2000'.freeze

  def initialize(integration)
    @integration = integration
    refresh_token_if_needed
  end

  # Devuelve { headers: [...], rows: [ { header => value }, ... ] }.
  # La primera fila se toma como encabezados.
  def read_table(file_id, range: nil)
    range = range.presence || DEFAULT_RANGE
    response = HTTParty.get(
      "#{SHEETS_API}/spreadsheets/#{file_id}/values/#{ERB::Util.url_encode(range)}",
      headers: { 'Authorization' => "Bearer #{@integration.access_token}" },
      query: { majorDimension: 'ROWS' }
    )
    raise "Sheets API error #{response.code}: #{response.body}" unless response.success?

    values = response.parsed_response['values'] || []
    return { headers: [], rows: [] } if values.empty?

    headers = values.first.map { |h| h.to_s.strip }
    rows = values.drop(1).map do |row|
      headers.each_with_index.to_h { |h, i| [h.presence || "col_#{i + 1}", row[i].to_s] }
    end
    { headers: headers, rows: rows }
  end

  def file_metadata(file_id)
    response = HTTParty.get(
      "https://www.googleapis.com/drive/v3/files/#{file_id}",
      headers: { 'Authorization' => "Bearer #{@integration.access_token}" },
      query: { fields: 'id,name,modifiedTime,trashed,mimeType' }
    )
    raise "Drive metadata error #{response.code}: #{response.body}" unless response.success?

    response.parsed_response
  end

  private

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
end
