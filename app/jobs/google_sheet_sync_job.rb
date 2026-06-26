# @knowledge_sources — Base de Conocimiento / Google Sheets
#
# Sincroniza una Google Sheet según su modo (config['sheet_mode']):
#   - 'faq'  : cada fila → un chunk vectorizado en knowledge_items (búsqueda semántica).
#   - 'data' : filas crudas en google_sheet_rows (consulta analítica exacta) + 1 item
#              "resumen" embebido con los encabezados, para que el bot ubique la hoja.
# Disparado por el botón "Sincronizar ahora".
class GoogleSheetSyncJob < ApplicationJob
  include KnowledgeEmbeddable
  queue_as :default

  def perform(action:, source_id:, account_id:)
    account = Account.find_by(id: account_id)
    return unless account

    source = account.knowledge_sources.find_by(id: source_id, source_type: 'google_sheet')
    return unless source

    case action
    when 'upsert'  then upsert_sheet(account, source)
    when 'destroy' then destroy_sheet(account, source)
    end
  rescue StandardError => e
    Rails.logger.error "[GoogleSheetSyncJob] #{e.message}"
    source&.update(sync_status: 'error', config: source.config.merge('last_error' => humanize_error(e.message)))
  end

  private

  def upsert_sheet(account, source)
    integration = find_integration(account, source)
    return unless integration

    file_id = source.config['file_id'].presence
    return if file_id.blank?

    svc   = GoogleSheetsService.new(integration)
    table = svc.read_table(file_id, range: source.config['sheet_range'])
    meta  = safe_metadata(svc, file_id)

    if source.config['sheet_mode'] == 'data'
      sync_data_mode(account, source, table)
    else
      sync_faq_mode(account, source, table)
    end

    source.update(
      last_synced_at: Time.current,
      sync_status: 'idle',
      config: source.config.merge('modified_time' => meta&.dig('modifiedTime')).except('last_error')
    )
  end

  # --- Modo FAQ: una fila = un chunk semántico ---------------------------------
  def sync_faq_mode(account, source, table)
    # Modo FAQ no usa google_sheet_rows: limpiamos por si cambió de modo.
    source.google_sheet_rows.delete_all

    rows = table[:rows]
    rows.each_with_index do |row, index|
      content = row.map { |h, v| "#{h}: #{v}" }.join("\n")
      next if content.strip.blank?

      embedding = generate_embedding(account, content)
      next unless embedding

      upsert_item(account, source, "#{source.name} — fila #{index + 1}", content, index, embedding)
    end
    delete_orphan_items(account, source, rows.size)
  end

  # --- Modo Datos: filas tipadas + 1 item resumen ------------------------------
  def sync_data_mode(account, source, table)
    # Refrescar filas: reemplazo completo (barato, no toca OpenAI).
    source.google_sheet_rows.delete_all
    now = Time.current
    records = table[:rows].each_with_index.map do |row, index|
      { account_id: account.id, knowledge_source_id: source.id, row_index: index,
        data: row, created_at: now, updated_at: now }
    end
    GoogleSheetRow.insert_all(records) if records.any?

    # 1 item resumen embebido: encabezados + nombre, para ubicar la hoja en la búsqueda.
    summary = "Hoja de datos: #{source.name}\nColumnas: #{table[:headers].join(', ')}\nFilas: #{table[:rows].size}"
    embedding = generate_embedding(account, summary)
    upsert_item(account, source, source.name, summary, 0, embedding) if embedding
    delete_orphan_items(account, source, 1)
  end

  def destroy_sheet(account, source)
    account.knowledge_items.where(source_type: 'google_sheet', source_id: source.id).destroy_all
    source.google_sheet_rows.delete_all
  end

  def upsert_item(account, source, title, content, index, embedding)
    item = KnowledgeItem.find_or_initialize_by(
      account_id: account.id, source_type: 'google_sheet', source_id: source.id, chunk_index: index
    )
    item.assign_attributes(
      knowledge_source_id: source.id,
      title: title,
      content: content,
      embedding: embedding,
      metadata: { file_id: source.config['file_id'], file_url: source.config['file_url'],
                  sheet_mode: source.config['sheet_mode'] }
    )
    item.save!
  end

  def delete_orphan_items(account, source, new_total)
    account.knowledge_items
           .where(source_type: 'google_sheet', source_id: source.id)
           .where('chunk_index >= ?', new_total)
           .destroy_all
  end

  def safe_metadata(svc, file_id)
    svc.file_metadata(file_id)
  rescue StandardError => e
    Rails.logger.warn "[GoogleSheetSyncJob] metadata no disponible: #{e.message}"
    nil
  end

  def find_integration(account, source)
    scope = UserCalendarIntegration.where(account_id: account.id)
    integration_id = source.config['integration_id']
    integration = scope.find_by(id: integration_id) if integration_id.present?
    integration || scope.first
  end

  def humanize_error(message)
    return 'Habilita la Google Sheets API en tu proyecto de Google Cloud (consola de GCP → APIs y servicios).' if message.include?('has not been used in project') || message.include?('accessNotConfigured') || message.include?('it is disabled')
    return 'Reconecta tu cuenta de Google: faltan permisos de Sheets/Drive (vuelve a autorizar).' if message.include?('SCOPE_INSUFFICIENT') || message.include?('insufficient')
    return 'No se pudo leer la hoja. Verifica que la cuenta de Google tenga acceso.' if message.include?('404') || message.include?('not found')

    message.to_s.truncate(180)
  end
end
