# @knowledge_sources
# Job para generar o actualizar el embedding de un ítem de conocimiento via OpenAI.
# Se dispara desde callbacks en CannedResponse (create/update/destroy).
class KnowledgeItemSyncJob < ApplicationJob
  queue_as :default

  def perform(action:, source_type:, source_id:, account_id:)
    account = Account.find_by(id: account_id)
    return unless account

    case action
    when 'upsert'
      upsert_item(account, source_type, source_id)
    when 'destroy'
      KnowledgeItem.where(account_id: account_id, source_type: source_type, source_id: source_id).destroy_all
    end
  end

  private

  def upsert_item(account, source_type, source_id)
    source = find_knowledge_source(account, source_type)
    return unless source

    record = find_record(account, source_type, source_id)
    return unless record

    content = extract_content(source_type, record)
    return if content.blank?

    embedding = generate_embedding(account, content)
    return unless embedding

    item = KnowledgeItem.find_or_initialize_by(
      account_id:  account.id,
      source_type: source_type,
      source_id:   source_id,
      chunk_index: 0
    )

    item.assign_attributes(
      knowledge_source_id: source.id,
      title: extract_title(source_type, record),
      content: content,
      embedding: embedding,
      metadata: build_metadata(source_type, record)
    )
    item.save!
  end

  def find_knowledge_source(account, source_type)
    account.knowledge_sources.active.find_by(source_type: source_type) ||
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

  def generate_embedding(account, text)
    api_key = openai_api_key(account)
    return unless api_key

    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KnowledgeItemSyncJob] Error generating embedding: #{e.message}"
    nil
  end

  # Cada cuenta usa su propia integración OpenAI (sin fallback a ENV global, multi-tenant).
  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end
end
