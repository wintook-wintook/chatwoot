# @knowledge_sources — Base de Conocimiento / Google Docs
#
# Exporta el contenido de un Google Doc como texto plano usando la Drive API,
# reutilizando la conexión OAuth de Google (UserCalendarIntegration + scope
# drive.readonly). Refresca el access_token si está vencido, igual que
# GoogleCalendarService.
class GoogleDocsService
  DRIVE_API = 'https://www.googleapis.com/drive/v3'.freeze
  TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze

  # Extrae el file_id de una URL de Google Docs o devuelve el valor tal cual si ya
  # parece un id (cuando el usuario pega el id directo en vez de la URL completa).
  #   https://docs.google.com/document/d/<ID>/edit  → <ID>
  def self.extract_file_id(url_or_id)
    value = url_or_id.to_s.strip
    return value if value.blank?

    match = value.match(%r{/d/([a-zA-Z0-9_-]+)}) || value.match(/[?&]id=([a-zA-Z0-9_-]+)/)
    match ? match[1] : value
  end

  def initialize(integration)
    @integration = integration
    refresh_token_if_needed
  end

  # Devuelve el texto plano del documento, o nil si no se pudo obtener.
  def export_text(file_id)
    response = HTTParty.get(
      "#{DRIVE_API}/files/#{file_id}/export",
      headers: { 'Authorization' => "Bearer #{@integration.access_token}" },
      query: { mimeType: 'text/plain' }
    )
    raise "Drive export error #{response.code}: #{response.body}" unless response.success?

    response.body.to_s
  end

  # Metadatos básicos del archivo (nombre, modifiedTime, trashed).
  def file_metadata(file_id)
    response = HTTParty.get(
      "#{DRIVE_API}/files/#{file_id}",
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
