# frozen_string_literal: true

# ================================================================================
# @knowledge_sources — SINCRONIZAR UN SITIO WORDPRESS
# ================================================================================
# Baja el contenido ELEGIDO de un sitio, lo limpia, lo trocea, lo vectoriza en
# lotes y lo deja en knowledge_items. Y borra lo que ya no corresponde.
#
# EN QUÉ SE DIFERENCIA DE GoogleDocSyncJob:
#   Ahí una fuente ES un documento, y los chunks van 0..N con source_id = source.id.
#   Acá una fuente son cientos de entradas, cada una con sus propios chunks, así que
#   source_id es el id de la ENTRADA en WordPress. Por eso el índice único tuvo que
#   incorporar knowledge_source_id: sin él, dos sitios de la misma cuenta con una
#   entrada #412 se pisaban entre sí.
#
# EL BORRADO ES LA PARTE QUE IMPORTA:
#   Hay tres formas de que un chunk sobre, y las tres terminan igual — el agente
#   contestando con contenido que el usuario cree haber quitado:
#     · la entrada se deseleccionó       ← la más fácil de olvidar
#     · la entrada se despublicó         ← deja de venir en la lista, no llega marcada
#     · la entrada se acortó             ← sobran los chunks del final
#   Si la pantalla dice una cosa y el motor hace otra, todo el módulo pierde sentido.
#
# LOS EMBEDDINGS VAN EN UN SOLO LOTE PARA TODO EL SITIO:
#   No de a una entrada. Medido: 8 ms por chunk en lotes llenos contra 239 de a uno.
#   Agrupar por entrada desperdiciaría el lote, porque una entrada son ~2 chunks.
# ================================================================================

class WordpressSyncJob < ApplicationJob
  include KnowledgeEmbeddable
  queue_as :default

  SOURCE_TYPE = 'wordpress'

  def perform(action:, source_id:, account_id:)
    account = Account.find_by(id: account_id)
    return unless account

    source = account.knowledge_sources.find_by(id: source_id, source_type: SOURCE_TYPE)
    return unless source

    case action
    when 'upsert'  then sync(account, source)
    when 'destroy' then destroy_all_items(account, source)
    end
  rescue StandardError => e
    Rails.logger.error "[WordpressSyncJob] #{e.class}: #{e.message}"
    source&.update(sync_status: 'error', config: source.config.merge('last_error' => e.message))
  end

  private

  def sync(account, source)
    source.update(sync_status: 'syncing')
    client = WordpressClient.new(source.config['site_url'])
    seleccion = Wordpress::Selection.new(client, source.config).call
    # nil = el sitio no respondió. NO se borra nada: leer ese vacío como "el
    # usuario deseleccionó todo" borraría el índice entero por un 403 pasajero.
    return finish_with_error(source, :unreachable) if seleccion.nil?

    entradas = fetch_entries(client, seleccion)

    indexed = index_entries(account, source, entradas)
    remove_unselected(account, source, indexed.keys)
    finish(source, indexed)
  end

  # Se baja el contenido completo de lo elegido. Un tipo que falle no cancela los
  # demás: es mejor indexar las entradas y perder los productos que no indexar nada.
  def fetch_entries(client, seleccion)
    return [] if seleccion.empty?

    entradas = seleccion.filter_map do |type, ids|
      result = client.items(type, ids: ids)
      next Rails.logger.warn("[WordpressSyncJob] #{type}: #{result.error}") && nil unless result.ok?

      result.data
    end

    entradas.flatten
  end

  # ── el índice ───────────────────────────────────────────────────────────────
  # Se trocea TODO primero y se vectoriza de una sola vez, porque el lote es lo que
  # hace la diferencia. Después se reparten los vectores por entrada.
  def index_entries(account, source, entradas)
    troceadas = entradas.filter_map do |entrada|
      chunks = Wordpress::Chunker.call(Wordpress::ContentCleaner.call(entrada[:html]))
      next if chunks.empty?

      [entrada, chunks]
    end

    vectores = generate_embeddings(account, troceadas.flat_map(&:last))
    cursor = 0
    indexed = {}

    troceadas.each do |entrada, chunks|
      slice = vectores[cursor, chunks.size] || []
      cursor += chunks.size
      guardados = upsert_entry(account, source, entrada, chunks, slice)
      indexed[entrada[:id]] = guardados if guardados.positive?
    end

    indexed
  end

  def upsert_entry(account, source, entrada, chunks, vectores)
    guardados = 0

    chunks.each_with_index do |chunk, index|
      embedding = vectores[index]
      # Un chunk sin vector no se guarda: una fila sin embedding nunca aparece en
      # una búsqueda y solo confunde los conteos de la pantalla.
      next if embedding.blank?

      upsert_item(account, source, entrada, { content: chunk, index: index, embedding: embedding })
      guardados += 1
    end

    # Si la entrada se acortó, sobran los chunks del final de la versión anterior.
    delete_chunks_from(account, source, entrada[:id], guardados)
    guardados
  end

  def upsert_item(account, source, entrada, chunk)
    item = KnowledgeItem.find_or_initialize_by(
      account_id: account.id, source_type: SOURCE_TYPE,
      knowledge_source_id: source.id, source_id: entrada[:id], chunk_index: chunk[:index]
    )
    item.assign_attributes(
      title: entrada[:title],
      content: chunk[:content],
      embedding: chunk[:embedding],
      metadata: { wp_type: entrada[:type], url: entrada[:url], modified: entrada[:modified] }
    )
    item.save!
  end

  # ── el borrado ──────────────────────────────────────────────────────────────
  # Lo que ya no está elegido, o se despublicó. Es el caso que sostiene todo el
  # módulo: si esto no corre, la pantalla dice una cosa y el agente hace otra.
  def remove_unselected(account, source, ids_vigentes)
    scope = items_of(account, source)
    scope = scope.where.not(source_id: ids_vigentes) if ids_vigentes.present?
    scope.delete_all
  end

  def delete_chunks_from(account, source, entry_id, total)
    items_of(account, source).where(source_id: entry_id).where(chunk_index: total..).delete_all
  end

  def destroy_all_items(account, source)
    items_of(account, source).delete_all
  end

  def items_of(account, source)
    account.knowledge_items.where(source_type: SOURCE_TYPE, knowledge_source_id: source.id)
  end

  # ── cierre ──────────────────────────────────────────────────────────────────
  def finish(source, indexed)
    source.update(
      last_synced_at: Time.current,
      sync_status: 'idle',
      config: source.config.merge('last_error' => nil,
                                  'indexed_entries' => indexed.size,
                                  'indexed_chunks' => indexed.values.sum)
    )
  end

  def finish_with_error(source, reason)
    source.update(sync_status: 'error', config: source.config.merge('last_error' => reason.to_s))
  end
end
