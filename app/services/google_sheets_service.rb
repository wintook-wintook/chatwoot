# @knowledge_sources — Base de Conocimiento / Google Sheets
#
# Lee y escribe los valores de una hoja vía Sheets API y los devuelve como
# encabezados + filas (array de hashes { encabezado => valor }). Reutiliza la
# conexión OAuth de Google (UserCalendarIntegration + scope spreadsheets, lectura+escritura).
class GoogleSheetsService
  SHEETS_API = 'https://sheets.googleapis.com/v4'.freeze
  TOKEN_URL  = 'https://oauth2.googleapis.com/token'.freeze
  # Techo de filas (no hay forma barata de saber cuántas usa el usuario sin otra llamada);
  # la columna SÍ se calcula real (ver `full_range`) — un rango fijo 'A1:Z2000' recortaba en
  # silencio cualquier hoja de más de 26 columnas (encontrado en la cuenta 1: la hoja real
  # de GRUAS tiene 29, las 3 últimas — incluida TEXTO_KB — nunca llegaban a la BD).
  MAX_ROWS = 2000

  def initialize(integration)
    @integration = integration
    refresh_token_if_needed
  end

  # Devuelve { headers: [...], rows: [ { header => value }, ... ] }.
  # La primera fila se toma como encabezados.
  def read_table(file_id, range: nil)
    range = range.presence || full_range(file_id)
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

  # Escribe una lista de celdas puntuales de una sola pasada (batchUpdate: 1 llamada para N
  # celdas, en vez de N llamadas). `updates` es un array de { range:, value: } con range en
  # notación A1 (ej. "AD2"). Requiere el scope de escritura completo (spreadsheets, no
  # spreadsheets.readonly) — con el token de solo-lectura esto devuelve 403.
  def update_cells(file_id, updates)
    return if updates.blank?

    body = {
      valueInputOption: 'RAW',
      data: updates.map { |u| { range: u[:range], majorDimension: 'ROWS', values: [[u[:value]]] } }
    }
    response = HTTParty.post(
      "#{SHEETS_API}/spreadsheets/#{file_id}/values:batchUpdate",
      headers: { 'Authorization' => "Bearer #{@integration.access_token}", 'Content-Type' => 'application/json' },
      body: body.to_json
    )
    raise "Sheets API error #{response.code}: #{response.body}" unless response.success?

    response.parsed_response
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

  # Metadata de la hoja (Sheets API, no Drive): título y cantidad real de columnas/filas de
  # la PRIMERA pestaña — para armar un rango de lectura que no recorte nada.
  def sheet_metadata(file_id)
    response = HTTParty.get(
      "#{SHEETS_API}/spreadsheets/#{file_id}",
      headers: { 'Authorization' => "Bearer #{@integration.access_token}" },
      query: { fields: 'sheets(properties(title,gridProperties))' }
    )
    raise "Sheets API error #{response.code}: #{response.body}" unless response.success?

    response.parsed_response.dig('sheets', 0, 'properties')
  end

  # Letra de columna A1 (1-indexed: 1 => "A", 27 => "AA").
  def self.column_letter(index)
    letters = ''
    while index.positive?
      index, remainder = (index - 1).divmod(26)
      letters = (65 + remainder).chr + letters
    end
    letters
  end

  private

  # Rango dinámico 'A1:<última_columna_real><MAX_ROWS>' — evita el recorte fijo de antes.
  # Si la metadata falla (permisos, hoja rara), cae al rango fijo de siempre (Z) para no
  # romper la sincronización por esto.
  def full_range(file_id)
    columns = sheet_metadata(file_id)&.dig('gridProperties', 'columnCount')
    return 'A1:Z2000' if columns.blank?

    "A1:#{self.class.column_letter(columns)}#{MAX_ROWS}"
  rescue StandardError => e
    Rails.logger.warn "[GoogleSheetsService] No se pudo leer columnCount, uso rango fijo: #{e.message}"
    'A1:Z2000'
  end

  def refresh_token_if_needed
    return unless @integration.token_expired?

    response = HTTParty.post(
      TOKEN_URL,
      body: {
        client_id: GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
        client_secret: GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil),
        refresh_token: @integration.refresh_token,
        grant_type: 'refresh_token'
      }
    )
    raise "Token refresh failed: #{response.body}" unless response.success?

    parsed = response.parsed_response
    @integration.update_tokens(
      access_token: parsed['access_token'],
      expires_at: Time.current + parsed['expires_in'].to_i.seconds
    )
  end
end
