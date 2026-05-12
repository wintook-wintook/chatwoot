# @knowledge_sources
# Job para sincronización inicial (bulk) de todos los topics de un foro Discourse.
# Si config['category_id'] está presente usa /c/:id/l/latest.json (solo esa categoría).
# Pagina hasta agotar resultados y encola DiscourseTopicSyncJob por cada topic.
class DiscourseKnowledgeSyncJob < ApplicationJob
  queue_as :default

  TOPICS_PER_PAGE = 30

  def perform(source_id:)
    source = KnowledgeSource.find_by(id: source_id, source_type: 'discourse')
    return unless source

    config      = source.config || {}
    base_url    = config['url'].to_s.chomp('/')
    category_id = config['category_id'].presence

    return if base_url.blank?

    total = 0
    page  = 0

    loop do
      topics = fetch_topics_page(config, base_url, category_id, page)
      break if topics.blank?

      topics.each do |topic|
        next if topic['id'].blank?
        next if topic['archetype'] == 'private_message'

        DiscourseTopicSyncJob.perform_later(
          source_id: source.id,
          topic_id:  topic['id'].to_i,
          action:    'upsert'
        )
        total += 1
      end

      break if topics.size < TOPICS_PER_PAGE

      page += 1
    end

    source.update(last_synced_at: Time.current)
    scope = category_id ? "category #{category_id}" : 'all categories'
    Rails.logger.info "[DiscourseKnowledgeSync] Source #{source.id} (#{scope}) — #{total} topics enqueued"
  end

  private

  def fetch_topics_page(config, base_url, category_id, page)
    path = category_id ? "/c/#{category_id}/l/latest.json" : '/latest.json'
    uri  = URI("#{base_url}#{path}")
    uri.query = URI.encode_www_form(page: page)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 20

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = config['api_key'].to_s if config['api_key'].present?
    request['Api-Username'] = config['api_username'].to_s.presence || 'system'
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('topic_list', 'topics') || []
  rescue StandardError => e
    Rails.logger.error "[DiscourseKnowledgeSync] Error fetching page #{page}: #{e.message}"
    []
  end
end
