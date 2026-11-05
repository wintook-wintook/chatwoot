# @knowledge_sources
# Job para generar o actualizar el embedding de un ítem de conocimiento via OpenAI.
# Se dispara desde callbacks en CannedResponse (create/update/destroy).
#
# proyecto@respuestas_predefinidas R1 (docs/respuestas_predefinidas_plan.md §3–4):
#   · error PASAJERO de OpenAI (sin red, timeout, 429 por límite, 5xx): se reintenta solo,
#     con espera creciente, hasta ATTEMPTS veces; al agotarse queda `failed`.
#   · error PERMANENTE (clave inválida, cuota agotada, texto rechazado): no se reintenta,
#     queda `failed` con el motivo.
#   · sin integración de OpenAI: `no_key` (antes no quedaba rastro).
#   El estado se guarda en la predefinida (embedding_status / embedding_error / embedded_at);
#   los artículos usan los mismos reintentos (D5) pero no guardan estado.
#   · la fuente de la cuenta se busca aunque esté desactivada: antes se intentaba crear otra,
#     chocaba con el índice único y no se vectorizaba nada.
class KnowledgeItemSyncJob < ApplicationJob
  queue_as :default

  ATTEMPTS = 5
  # Se puede volver a intentar: lo resuelve esperar.
  class TransientError < StandardError; end
  # No se arregla esperando: el motivo va a la pantalla.
  class PermanentError < StandardError; end

  retry_on TransientError, wait: :exponentially_longer, attempts: ATTEMPTS do |job, error|
    job.mark_failed(error.message.presence || 'temporary')
  end

  def perform(action:, source_type:, source_id:, account_id:)
    @source_type = source_type
    @source_id = source_id
    account = Account.find_by(id: account_id)
    return unless account

    case action
    when 'upsert'
      upsert_item(account, source_type, source_id)
    when 'destroy'
      KnowledgeItem.where(account_id: account_id, source_type: source_type, source_id: source_id).destroy_all
    end
  end

  # Público: lo llama retry_on al agotar los reintentos.
  def mark_failed(motivo)
    args = arguments.first.to_h.symbolize_keys
    @source_type ||= args[:source_type]
    @source_id ||= args[:source_id]
    mark(embedding_status: 'failed', embedding_error: motivo.to_s.first(255))
  end

  private

  # Solo las predefinidas guardan su estado (los artículos no tienen esas columnas).
  def mark(attrs)
    return unless @source_type == 'canned_response'

    CannedResponse.where(id: @source_id).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
  end

  def upsert_item(account, source_type, source_id)
    source = find_knowledge_source(account, source_type)
    return unless source

    record = find_record(account, source_type, source_id)
    return unless record

    content = extract_content(source_type, record)
    return if content.blank?

    embedding = generate_embedding(account, content)
    return mark(embedding_status: 'no_key', embedding_error: nil) if embedding == :no_key

    save_item(account, source, record, content, embedding)
    mark(embedding_status: 'ready', embedding_error: nil, embedded_at: Time.current)
  rescue PermanentError => e
    mark(embedding_status: 'failed', embedding_error: e.message)
  end

  def save_item(account, source, record, content, embedding)
    item = KnowledgeItem.find_or_initialize_by(account_id: account.id, source_type: @source_type,
                                               source_id: @source_id, chunk_index: 0)
    item.update!(knowledge_source_id: source.id, title: extract_title(@source_type, record), content: content,
                 embedding: embedding, metadata: build_metadata(@source_type, record))
  end

  # La activa, o la que haya aunque esté desactivada: hay una sola por cuenta
  # (idx_unique_native_knowledge_sources) y crear otra truena.
  def find_knowledge_source(account, source_type)
    account.knowledge_sources.active.find_by(source_type: source_type) ||
      account.knowledge_sources.find_by(source_type: source_type) ||
      account.knowledge_sources.create!(
        source_type: source_type,
        name: knowledge_source_name(source_type, account),
        status: 'active'
      )
  end

  # Nombre localizado según el idioma de la cuenta. 'article' es el Centro de Ayuda
  # nativo de Chatwoot (Help Center). Ver config/locales/*.yml → knowledge_sources.names
  def knowledge_source_name(source_type, account)
    I18n.t("knowledge_sources.names.#{source_type}",
           locale: account.locale.presence || I18n.default_locale,
           default: source_type.humanize)
  end

  def find_record(account, source_type, source_id)
    case source_type
    when 'canned_response'
      account.canned_responses.find_by(id: source_id)
    when 'article' # @tickets_cases 2H
      account.articles.find_by(id: source_id)
    end
  end

  def extract_content(source_type, record)
    case source_type
    when 'canned_response'
      "#{record.short_code}: #{record.content}"
    when 'article' # @tickets_cases 2H — título + descripción + cuerpo (sin etiquetas).
      [record.title, record.description, strip_html(record.content)].compact_blank.join("\n\n")
    end
  end

  def extract_title(source_type, record)
    case source_type
    when 'canned_response'
      record.short_code
    when 'article'
      record.title
    end
  end

  def build_metadata(source_type, record)
    case source_type
    when 'canned_response'
      { short_code: record.short_code }
    when 'article' # @tickets_cases 2H
      { article_id: record.id, portal_id: record.portal_id, category_id: record.category_id,
        slug: record.slug, status: record.status }
    else
      {}
    end
  end

  # Quita etiquetas HTML básicas del contenido del artículo para vectorizar texto plano.
  def strip_html(text)
    return text if text.blank?

    ActionView::Base.full_sanitizer.sanitize(text)
  end

  # El vector; :no_key sin integración. Un error de OpenAI sube como TransientError
  # (se reintenta) o PermanentError (queda el motivo).
  def generate_embedding(account, text)
    api_key = openai_api_key(account)
    return :no_key unless api_key

    response = request_embedding(api_key, text)
    raise_for(response) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding') || raise(PermanentError, 'empty_response')
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError => e
    Rails.logger.warn "[KnowledgeItemSyncJob] OpenAI no respondió: #{e.class}"
    raise TransientError, 'no_connection'
  end

  def request_embedding(api_key, text)
    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 20

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json
    http.request(request)
  end

  # 429 por límite de llamadas o 5xx: esperar sirve. 429 por cuota, 401 o 400: no.
  def raise_for(response)
    codigo = response.code.to_i
    detalle = JSON.parse(response.body.to_s).dig('error', 'code').to_s rescue '' # rubocop:disable Style/RescueModifier
    Rails.logger.error "[KnowledgeItemSyncJob] OpenAI HTTP #{codigo} #{detalle}"
    raise PermanentError, 'quota' if detalle == 'insufficient_quota'
    raise TransientError, "http_#{codigo}" if codigo == 429 || codigo >= 500
    raise PermanentError, 'invalid_key' if [401, 403].include?(codigo)

    raise PermanentError, "http_#{codigo}"
  end

  # Cada cuenta usa su propia integración OpenAI (sin fallback a ENV global, multi-tenant).
  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end
end
