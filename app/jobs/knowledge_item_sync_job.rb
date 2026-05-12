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
      account_id: account.id,
      source_type: source_type,
      source_id: source_id
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
        name: source_type == 'canned_response' ? 'Respuestas Predefinidas' : source_type.humanize,
        status: 'active'
      )
  end

  def find_record(account, source_type, source_id)
    case source_type
    when 'canned_response'
      account.canned_responses.find_by(id: source_id)
    end
  end

  def extract_content(source_type, record)
    case source_type
    when 'canned_response'
      "#{record.short_code}: #{record.content}"
    end
  end

  def extract_title(source_type, record)
    case source_type
    when 'canned_response'
      record.short_code
    end
  end

  def build_metadata(source_type, record)
    case source_type
    when 'canned_response'
      { short_code: record.short_code }
    else
      {}
    end
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

  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end
end
