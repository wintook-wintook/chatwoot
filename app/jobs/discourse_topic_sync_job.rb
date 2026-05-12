# @knowledge_sources
# Job para sincronizar un topic individual de Discourse.
# Obtiene el contenido via API, genera embedding y hace upsert/delete en knowledge_items.
class DiscourseTopicSyncJob < ApplicationJob
  queue_as :default

  def perform(source_id:, topic_id:, action:)
    source  = KnowledgeSource.find_by(id: source_id)
    return unless source

    account = source.account
    config  = source.config || {}

    case action
    when 'upsert'
      upsert_topic(account, source, config, topic_id)
    when 'destroy'
      KnowledgeItem.where(account_id: account.id, source_type: 'discourse', source_id: topic_id).destroy_all
    end
  end

  private

  def upsert_topic(account, source, config, topic_id)
    topic = fetch_topic(config, topic_id)
    return unless topic

    title   = topic['title'].to_s.strip
    content = extract_content(topic)
    return if content.blank?

    text_to_embed = "#{title}\n\n#{content}"
    embedding = generate_embedding(account, text_to_embed)
    return unless embedding

    item = KnowledgeItem.find_or_initialize_by(
      account_id:  account.id,
      source_type: 'discourse',
      source_id:   topic_id
    )

    item.assign_attributes(
      knowledge_source_id: source.id,
      title:     title,
      content:   content,
      embedding: embedding,
      metadata:  {
        url:      "#{config['url'].to_s.chomp('/')}/t/#{topic['slug']}/#{topic_id}",
        tags:     topic['tags'] || [],
        category: topic['category_id']
      }
    )
    item.save!

    Rails.logger.info "[DiscourseTopicSync] Upserted topic #{topic_id} — #{title}"
  end

  def fetch_topic(config, topic_id)
    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['api_username'].to_s.presence || 'system'

    uri  = URI("#{base_url}/t/#{topic_id}.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = api_key
    request['Api-Username'] = api_username
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "[DiscourseTopicSync] Error fetching topic #{topic_id}: #{e.message}"
    nil
  end

  def extract_content(topic)
    first_post = topic.dig('post_stream', 'posts', 0)
    return unless first_post

    cooked = first_post['cooked'].to_s
    ActionView::Base.full_sanitizer.sanitize(cooked).squish
  end

  def generate_embedding(account, text)
    api_key = openai_api_key(account)
    return unless api_key

    uri  = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[DiscourseTopicSync] Error generating embedding: #{e.message}"
    nil
  end

  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end
end
