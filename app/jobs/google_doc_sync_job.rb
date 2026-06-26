# @knowledge_sources — Base de Conocimiento / Google Docs
#
# Sincroniza un Google Doc hacia knowledge_items: descarga el texto, lo parte en
# chunks, genera embeddings por chunk y hace upsert. Borra los chunks huérfanos si
# el documento se achicó. Disparado por el botón "Sincronizar ahora".
#
# A diferencia de canned_response/article (un item por registro), aquí cada
# KnowledgeSource ES un documento; los knowledge_items usan source_id = source.id
# y chunk_index 0..N-1.
class GoogleDocSyncJob < ApplicationJob
  include KnowledgeEmbeddable
  queue_as :default

  # Tamaño de chunk en caracteres (~1000 tokens) con solapamiento para no cortar ideas.
  CHUNK_SIZE    = 4000
  CHUNK_OVERLAP = 400

  def perform(action:, source_id:, account_id:)
    account = Account.find_by(id: account_id)
    return unless account

    source = account.knowledge_sources.find_by(id: source_id, source_type: 'google_doc')
    return unless source

    case action
    when 'upsert'  then upsert_doc(account, source)
    when 'destroy' then destroy_doc(account, source)
    end
  rescue StandardError => e
    Rails.logger.error "[GoogleDocSyncJob] #{e.message}"
    source&.update(sync_status: 'error', config: source.config.merge('last_error' => humanize_error(e.message)))
  end

  private

  def upsert_doc(account, source)
    integration = find_integration(account, source)
    return unless integration

    file_id = source.config['file_id'].presence
    return if file_id.blank?

    docs    = GoogleDocsService.new(integration)
    text    = docs.export_text(file_id).to_s
    return if text.blank?

    meta   = safe_metadata(docs, file_id)
    chunks = build_chunks(text)
    title  = meta&.dig('name').presence || source.name

    chunks.each_with_index do |chunk, index|
      embedding = generate_embedding(account, chunk)
      next unless embedding

      upsert_item(account, source, title, chunk, index, embedding, meta)
    end

    delete_orphan_chunks(account, source, chunks.size)
    source.update(
      last_synced_at: Time.current,
      sync_status: 'idle',
      config: source.config.merge('modified_time' => meta&.dig('modifiedTime'))
    )
  end

  def destroy_doc(account, source)
    account.knowledge_items
           .where(source_type: 'google_doc', source_id: source.id)
           .destroy_all
  end

  def upsert_item(account, source, title, content, index, embedding, meta)
    item = KnowledgeItem.find_or_initialize_by(
      account_id:  account.id,
      source_type: 'google_doc',
      source_id:   source.id,
      chunk_index: index
    )
    item.assign_attributes(
      knowledge_source_id: source.id,
      title: title,
      content: content,
      embedding: embedding,
      metadata: {
        file_id: source.config['file_id'],
        file_url: source.config['file_url'],
        modified_time: meta&.dig('modifiedTime')
      }
    )
    item.save!
  end

  # Borra los chunks que sobraron de una versión anterior más larga del documento.
  def delete_orphan_chunks(account, source, new_total)
    account.knowledge_items
           .where(source_type: 'google_doc', source_id: source.id)
           .where('chunk_index >= ?', new_total)
           .destroy_all
  end

  def build_chunks(text)
    clean = text.gsub(/\r\n?/, "\n").strip
    return [clean] if clean.length <= CHUNK_SIZE

    chunks = []
    start  = 0
    while start < clean.length
      chunks << clean[start, CHUNK_SIZE]
      start += CHUNK_SIZE - CHUNK_OVERLAP
    end
    chunks
  end

  # Metadatos del archivo; si falla no rompe el sync (el texto ya se obtuvo).
  def safe_metadata(docs, file_id)
    docs.file_metadata(file_id)
  rescue StandardError => e
    Rails.logger.warn "[GoogleDocSyncJob] metadata no disponible: #{e.message}"
    nil
  end

  # Traduce los errores técnicos más comunes de Google a un mensaje accionable.
  def humanize_error(message)
    return 'Habilita la Google Drive API en tu proyecto de Google Cloud (consola de GCP → APIs y servicios).' if message.include?('has not been used in project') || message.include?('accessNotConfigured') || message.include?('it is disabled')
    return 'Reconecta tu cuenta de Google: faltan permisos de Drive (vuelve a autorizar).' if message.include?('SCOPE_INSUFFICIENT') || message.include?('insufficient')
    return 'No se pudo leer el documento. Verifica que la cuenta de Google tenga acceso.' if message.include?('404') || message.include?('File not found')
    return 'Ese archivo no es un Google Doc de texto exportable (¿es una Hoja de cálculo?).' if message.include?('Export only supports') || message.include?('fileNotExportable')

    message.to_s.truncate(180)
  end

  def find_integration(account, source)
    scope = UserCalendarIntegration.where(account_id: account.id)
    integration_id = source.config['integration_id']
    integration = scope.find_by(id: integration_id) if integration_id.present?
    integration || scope.first
  end
end
